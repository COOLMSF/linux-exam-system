from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import settings
from .database import dm8_engine, get_dm8_db
from .models import Agent, Base, Exam, Result, Student
from .schemas import (
    AgentAuthRequest,
    AgentAuthResponse,
    EncryptedResultUpload,
    ExamCreateRequest,
    ExamResponse,
    ResultUploadResponse,
)
from .security import create_agent_token, decrypt_payload, verify_checksum
from .ws_manager import ws_manager

app = FastAPI(title=settings.api_title, version=settings.api_version)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=dm8_engine)


@app.post("/api/v1/agent/auth", response_model=AgentAuthResponse)
def agent_auth(payload: AgentAuthRequest, db: Session = Depends(get_dm8_db)) -> AgentAuthResponse:
    student = db.scalar(select(Student).where(Student.student_no == payload.student_no))
    if not student or not student.is_active:
        raise HTTPException(status_code=401, detail="student not found or inactive")

    agent = db.scalar(select(Agent).where(Agent.agent_id == payload.agent_id))
    if not agent:
        agent = Agent(
            agent_id=payload.agent_id,
            student_id=student.id,
            hostname=payload.hostname,
            os_version=payload.os_version,
            status="online",
            last_seen_at=datetime.utcnow(),
        )
        db.add(agent)
    else:
        agent.status = "online"
        agent.last_seen_at = datetime.utcnow()
        agent.hostname = payload.hostname
        agent.os_version = payload.os_version
    db.commit()

    token = create_agent_token(payload.agent_id, payload.student_no)
    return AgentAuthResponse(access_token=token, expires_minutes=settings.jwt_expire_minutes)


@app.post("/api/v1/exams", response_model=ExamResponse)
def create_exam(payload: ExamCreateRequest, db: Session = Depends(get_dm8_db)) -> Exam:
    exam = Exam(
        name=payload.name,
        description=payload.description,
        start_time=payload.start_time,
        end_time=payload.end_time,
        status="draft",
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return exam


@app.get("/api/v1/exams", response_model=list[ExamResponse])
def list_exams(db: Session = Depends(get_dm8_db)) -> list[Exam]:
    return list(db.scalars(select(Exam).order_by(Exam.id.desc())).all())


@app.post("/api/v1/results/upload", response_model=ResultUploadResponse)
async def upload_result(payload: EncryptedResultUpload, db: Session = Depends(get_dm8_db)) -> ResultUploadResponse:
    if not verify_checksum(payload.ciphertext_b64, payload.sha256):
        raise HTTPException(status_code=400, detail="invalid checksum")

    body = decrypt_payload(payload.nonce_b64, payload.ciphertext_b64)
    required = {"exam_id", "student_no", "agent_id", "score"}
    if not required.issubset(body.keys()):
        raise HTTPException(status_code=400, detail="missing fields in payload")

    student = db.scalar(select(Student).where(Student.student_no == body["student_no"]))
    if not student:
        raise HTTPException(status_code=404, detail="student not found")

    result = Result(
        exam_id=int(body["exam_id"]),
        student_id=student.id,
        agent_id=str(body["agent_id"]),
        score=int(body["score"]),
        detail_json=body.get("detail_json"),
    )
    db.add(result)
    db.commit()
    db.refresh(result)

    await ws_manager.broadcast(
        int(body["exam_id"]),
        {
            "type": "result_uploaded",
            "result_id": result.id,
            "student_no": student.student_no,
            "score": result.score,
            "uploaded_at": result.uploaded_at.isoformat(),
        },
    )

    return ResultUploadResponse(success=True, result_id=result.id)


@app.websocket("/ws/status/{exam_id}")
async def ws_exam_status(websocket: WebSocket, exam_id: int) -> None:
    await ws_manager.connect(exam_id, websocket)
    try:
        while True:
            # Keepalive/read loop
            await websocket.receive_text()
    except WebSocketDisconnect:
        await ws_manager.disconnect(exam_id, websocket)
