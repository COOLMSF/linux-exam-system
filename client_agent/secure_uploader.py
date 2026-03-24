#!/usr/bin/env python3
"""Encrypted result uploader with offline retry queue."""

from __future__ import annotations

import base64
import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

QUEUE_FILE = Path.home() / ".exam_agent" / "pending_uploads.jsonl"
QUEUE_FILE.parent.mkdir(parents=True, exist_ok=True)


@dataclass
class UploadConfig:
    upload_url: str
    shared_key: str
    timeout_seconds: int = 20


class SecureResultUploader:
    def __init__(self, cfg: UploadConfig):
        self.cfg = cfg
        # key length should be 16/24/32; here enforce 32-byte via sha256
        self._key = hashlib.sha256(cfg.shared_key.encode("utf-8")).digest()

    def _encrypt_payload(self, payload: dict[str, Any]) -> dict[str, str]:
        aesgcm = AESGCM(self._key)
        nonce = hashlib.sha256(f"{time.time_ns()}".encode("utf-8")).digest()[:12]
        plaintext = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        ciphertext = aesgcm.encrypt(nonce, plaintext, None)
        ciphertext_b64 = base64.b64encode(ciphertext).decode("utf-8")
        return {
            "nonce_b64": base64.b64encode(nonce).decode("utf-8"),
            "ciphertext_b64": ciphertext_b64,
            "sha256": hashlib.sha256(ciphertext_b64.encode("utf-8")).hexdigest(),
        }

    def queue_result(self, payload: dict[str, Any]) -> None:
        with QUEUE_FILE.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(payload, ensure_ascii=False) + "\n")

    def flush_queue(self) -> int:
        if not QUEUE_FILE.exists():
            return 0
        lines = QUEUE_FILE.read_text(encoding="utf-8").splitlines()
        if not lines:
            return 0

        remaining: list[str] = []
        success_count = 0
        for line in lines:
            if not line.strip():
                continue
            raw_payload = json.loads(line)
            if self._try_upload(raw_payload):
                success_count += 1
            else:
                remaining.append(line)

        QUEUE_FILE.write_text("\n".join(remaining) + ("\n" if remaining else ""), encoding="utf-8")
        return success_count

    def _try_upload(self, raw_payload: dict[str, Any]) -> bool:
        encrypted = self._encrypt_payload(raw_payload)
        try:
            resp = requests.post(
                self.cfg.upload_url,
                json=encrypted,
                timeout=self.cfg.timeout_seconds,
            )
            return resp.status_code == 200
        except requests.RequestException:
            return False

    def upload_or_queue(self, payload: dict[str, Any]) -> bool:
        if self._try_upload(payload):
            self.flush_queue()
            return True
        self.queue_result(payload)
        return False
