#!/usr/bin/env python3
"""Generate deterministic KDF test vectors for msgr E2EE (docs/e2ee_spec.md)."""

from __future__ import annotations

import hashlib
import hmac
import json
from pathlib import Path

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF


def b64(data: bytes) -> str:
    import base64

    return base64.b64encode(data).decode("ascii")


def hkdf(ikm: bytes, info: bytes, length: int, salt: bytes | None = None) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=length,
        salt=salt if salt is not None else bytes(32),
        info=info,
    ).derive(ikm)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "flutter_frontend/packages/libmsgr_core/test/vectors"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Fixed IKM material (not real X25519 output — exercises KDF only).
    dh1 = bytes(range(32))
    dh2 = bytes(range(32, 64))
    dh3 = bytes(range(64, 96))
    xx_ikm = dh1 + dh2 + dh3
    xx_sk = hkdf(xx_ikm, b"msgr-e2ee-xx-v1", 32)

    root_key = bytes((i * 3) % 256 for i in range(32))
    dh_out = bytes((i * 5) % 256 for i in range(32))
    rk_out = hkdf(dh_out, b"msgr-e2ee-root-v1", 64, salt=root_key)

    chain_key = bytes((i * 7) % 256 for i in range(32))
    mk = hmac.new(chain_key, b"\x01", hashlib.sha256).digest()
    next_ck = hmac.new(chain_key, b"\x02", hashlib.sha256).digest()
    expanded = hkdf(mk, b"msgr-e2ee-msg-v1", 44)

    x3dh_ikm = dh1 + dh2 + dh3 + bytes(range(96, 128))
    x3dh_sk = hkdf(x3dh_ikm, b"msgr-e2ee-x3dh-v1", 32)

    vectors = {
        "xx_shared_secret": {
            "ikm": b64(xx_ikm),
            "sk": b64(xx_sk),
        },
        "x3dh_shared_secret": {
            "ikm": b64(x3dh_ikm),
            "sk": b64(x3dh_sk),
        },
        "kdf_rk": {
            "root_key": b64(root_key),
            "dh_out": b64(dh_out),
            "new_root_key": b64(rk_out[:32]),
            "chain_key": b64(rk_out[32:]),
        },
        "kdf_ck": {
            "chain_key": b64(chain_key),
            "message_key": b64(mk),
            "next_chain_key": b64(next_ck),
        },
        "expand_message_key": {
            "message_key": b64(mk),
            "aes_key": b64(expanded[:32]),
            "nonce": b64(expanded[32:]),
        },
    }

    out_path = out_dir / "kdf_vectors.json"
    out_path.write_text(json.dumps(vectors, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
