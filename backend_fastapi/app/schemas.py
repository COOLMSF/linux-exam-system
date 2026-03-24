from datetime import datetime

from pydantic import BaseModel, Field


class AgentAuthRequest(BaseModel):
    agent_id: str
    student_no: str
    hostname: str | None = None
    os_version: str | None = None


class AgentAuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_minutes: int


class ExamCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None


class ExamResponse(BaseModel):
    id: int
    name: str
    description: str | None
    status: str
    start_time: datetime | None
    end_time: datetime | None
    created_at: datetime

    class Config:
        from_attributes = True


class EncryptedResultUpload(BaseModel):
    nonce_b64: str
    ciphertext_b64: str
    sha256: str


class ResultUploadResponse(BaseModel):
    success: bool
    result_id: int
