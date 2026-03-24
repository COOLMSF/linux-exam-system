import base64
import hashlib
import json
from datetime import datetime, timedelta, timezone
from typing import Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from jose import jwt

from .config import settings


def create_agent_token(agent_id: str, student_no: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": agent_id, "student_no": student_no, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def verify_checksum(ciphertext_b64: str, expected_sha256: str) -> bool:
    digest = hashlib.sha256(ciphertext_b64.encode("utf-8")).hexdigest()
    return digest == expected_sha256


def decrypt_payload(nonce_b64: str, ciphertext_b64: str) -> dict[str, Any]:
    key = hashlib.sha256(settings.upload_shared_key.encode("utf-8")).digest()
    nonce = base64.b64decode(nonce_b64.encode("utf-8"))
    ciphertext = base64.b64decode(ciphertext_b64.encode("utf-8"))
    plaintext = AESGCM(key).decrypt(nonce, ciphertext, None)
    return json.loads(plaintext.decode("utf-8"))
