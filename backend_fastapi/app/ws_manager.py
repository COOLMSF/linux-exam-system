import asyncio
from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._room_connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, exam_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._room_connections[exam_id].add(websocket)

    async def disconnect(self, exam_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            if exam_id in self._room_connections:
                self._room_connections[exam_id].discard(websocket)

    async def broadcast(self, exam_id: int, message: dict) -> None:
        async with self._lock:
            sockets = list(self._room_connections.get(exam_id, set()))
        for ws in sockets:
            try:
                await ws.send_json(message)
            except Exception:
                await self.disconnect(exam_id, ws)


ws_manager = ConnectionManager()
