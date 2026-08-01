# Msgr E2EE Specification (1:1 text)

Status: normative for issue #195  
Scope: personal-mode 1:1 text only. Media CEK (#236) and Sender Keys (#237) are out of scope.

## 1. Hard constraints

### Forbidden

- Assume the initiator already has the peer identity/device key locally before send
  (`if peerKey == null abort`).
- IK-style rejection because a peer public key is missing from a “known keys” DB.
- UI/send hard-gate on key-directory fetch success.
- Noise NK/IK semantics for peer content E2EE (“public keys are known”).

### Required

- **XX-style in-band handshake**: identity keys travel in `init` / `init_ack`.
- Key Directory is an **optional async optimization**, never a send prerequisite.
- First envelope is self-describing (sender IK + EK). Responder bootstraps from the
  received message alone.
- TOFU: first observed peer identity key is trusted; fingerprint UI is later work.

## 2. Locked product decisions

1. **First send is handshake-only `init`.** No plaintext/ciphertext body in `init`.
   UI may show “connecting…”. Queued text is sent as the first `msg` only after
   `init_ack`.
2. **Temporary server fan-out** of `init` with `rid: "*"` to all active devices on
   the recipient profile. Better device discovery: #235.
3. **Self-devices:** every `msg` also wraps the payload key to the sender’s other
   devices so history syncs E2EE across own phones.
4. **XX primary path.** Async prekey path is optional; empty/missing bundle must
   not fail send.

## 3. Cryptosuite

| Primitive | Choice |
|-----------|--------|
| DH | X25519 |
| Signatures | Ed25519 (identity signing key from `KeyManager`; no XEdDSA) |
| KDF_RK | `HKDF-SHA256(salt=root_key, ikm=dh_out, info="msgr-e2ee-root-v1", length=64)` → 32B new root key ‖ 32B chain key |
| KDF_CK | `HMAC-SHA256(chain_key, 0x01)` → message key; `HMAC-SHA256(chain_key, 0x02)` → next chain key |
| Message key expand | `HKDF-SHA256(salt=32×0x00, ikm=mk, info="msgr-e2ee-msg-v1", length=44)` → 32B AES key ‖ 12B nonce |
| AEAD | AES-256-GCM |
| Associated data | `sender_ik (32) ‖ recipient_ik (32) ‖ header_bytes` |
| MAX_SKIP | 1000 skipped message keys per session |

For `init`, `recipient_ik` in AD is 32 zero bytes (peer IK not yet known).

### Header encoding (`header_bytes`)

```
dh_public (32 bytes) || pn (uint32 BE) || n (uint32 BE)
```

### XX shared secret

```
SK = HKDF-SHA256(
  salt = 32×0x00,
  ikm  = DH(EK_a, IK_b) || DH(IK_a, EK_b) || DH(EK_a, EK_b),
  info = "msgr-e2ee-xx-v1",
  length = 32
)
```

Alice (initiator) and Bob (responder) both derive the same `SK`, then initialize the
Double Ratchet:

- Root key ← `SK`
- Alice sets her ratchet DH keypair to a fresh X25519 pair `DHs` and sends
  `DHs.public` in the first `msg` header after ack (or may include an initial
  ratchet public in `init_ack` handling — see §5).
- Concrete ratchet init (Signal-compatible shape):

**After XX SK is derived:**

1. Both parties set `RK = SK`.
2. Alice (initiator) generates `DHs = GENERATE_DH()`, sets `DHr = EK_b` (Bob’s
   ephemeral from `init_ack` is treated as his first ratchet public), then
   `kdf_rk(RK, DH(DHs, DHr))` → `(RK, CKs)`, `Ns = 0`, `Nr = 0`, `PN = 0`,
   empty skipped keys.
3. Bob (responder) sets `DHs = EK_b` (the ephemeral he published), `DHr = null`
   until Alice’s first `msg`, `CKs/CKr` empty, counters 0. On first decrypt he
   performs DH ratchet with Alice’s header.dh.

### Optional async prekey (secondary)

Only when a bundle is fetched at send-time:

```
SK = HKDF-SHA256(
  salt = 32×0x00,
  ikm  = DH(IK_a, SPK_b) || DH(EK_a, IK_b) || DH(EK_a, SPK_b) [|| DH(EK_a, OPK_b)],
  info = "msgr-e2ee-x3dh-v1",
  length = 32
)
```

Missing/empty bundle → fall back to XX. Never throw solely because bundle is absent.

## 4. Wire format

Envelope lives in the existing message `payload` map. All binary fields are
standard base64 (not base64url).

### Init (no body)

```json
{
  "v": 1,
  "e2ee": {
    "sid": "<sender device id>",
    "iv_ct": null,
    "keys": [
      {
        "rid": "*",
        "type": "init",
        "ik": "<base64 IK_a>",
        "ek": "<base64 EK_a>",
        "spk_id": null,
        "opk_id": null,
        "header": { "dh": "<base64>", "pn": 0, "n": 0 },
        "ct": null
      }
    ]
  }
}
```

`kind` on the message must be `"encrypted"`. `body` is empty string.

### Init ack

```json
{
  "v": 1,
  "e2ee": {
    "sid": "<bob device id>",
    "iv_ct": null,
    "keys": [
      {
        "rid": "<alice device id>",
        "type": "init_ack",
        "ik": "<base64 IK_b>",
        "ek": "<base64 EK_b>",
        "header": { "dh": "<base64 EK_b or DHs>", "pn": 0, "n": 0 },
        "ct": null
      }
    ]
  }
}
```

### Message (after session)

```json
{
  "v": 1,
  "e2ee": {
    "sid": "<sender device id>",
    "iv_ct": "<base64 AES-GCM(payload_key, utf8(plaintext))>",
    "keys": [
      {
        "rid": "<recipient device id>",
        "type": "msg",
        "ik": null,
        "ek": null,
        "header": { "dh": "<base64>", "pn": 0, "n": 3 },
        "ct": "<base64 ratchet-AEAD(payload_key)>"
      }
    ]
  }
}
```

`keys[]` MUST include one entry per known recipient device **and** each of the
sender’s other devices (self-sync).

### Message kinds

| `type` | Body (`iv_ct`) | Purpose |
|--------|----------------|---------|
| `init` | null | XX offer; `rid` may be `"*"` |
| `init_ack` | null | XX complete; targeted `rid` |
| `prekey` | optional | Async prekey bootstrap (secondary) |
| `msg` | required | Normal encrypted text |

## 5. Session flows

### 5.1 XX send without session

1. Alice enqueues plaintext locally.
2. Alice sends `init` (`rid: "*"`), no body.
3. Server fans out to all active devices on Bob’s profile.
4. Each Bob device that processes `init` may reply with `init_ack` targeted at
   Alice’s `sid`. First successful ack Alice accepts establishes the session for
   that `(alice_device, bob_device)` pair; others are ignored or establish
   additional per-device sessions.
5. Alice derives SK, initializes ratchet, flushes queued plaintext as `msg`
   (wrap to Bob devices + Alice’s other devices).

### 5.2 Concurrent init tie-break

If both sides send `init` before either ack:

- Lexicographically **lowest** `sid` (UTF-8 string compare) is treated as the
  initiator.
- The peer with the higher `sid` abandons its outbound pending init for that
  pair and responds with `init_ack` to the received init.
- The peer with the lower `sid` ignores a concurrent init from the higher sid
  and waits for `init_ack`.

### 5.3 Encrypt path (`msg`)

1. Generate random 32-byte `payload_key`.
2. `iv_ct = AES-GCM(payload_key, plaintext)` with random 12-byte nonce prepended
   to ciphertext+tag as a single blob: `nonce(12) || ciphertext || tag(16)`.
3. For each target device session, `ct = ratchet.encrypt(payload_key)`.
4. Assemble envelope; set message `kind = "encrypted"`, `body = ""`.

### 5.4 Decrypt path

1. Find `keys[]` entry where `rid == local_device_id` (or `rid == "*"` for init).
2. For `init`: store pending remote IK/EK; send `init_ack`; do not expect body.
3. For `init_ack`: derive SK; init ratchet; flush outbound queue.
4. For `msg`: `payload_key = ratchet.decrypt(header, ct)`; then
   `plaintext = AES-GCM-decrypt(payload_key, iv_ct)`.

## 6. Backend requirements

- Accept `kind: "encrypted"` with empty `body`; persist/fan-out `payload` opaque.
- `rid: "*"` init: fan-out to all active devices on the recipient profile.
- Optional key directory:
  - `PUT /api/v1/e2ee/keys` — upload identity/signed-prekey/OPK batch
  - `GET /api/v1/e2ee/bundles/:profile_id` — may return empty; not an error for clients
  - `GET /api/v1/e2ee/keys/count` — remaining OPKs
- Server MUST NOT validate or inspect envelope cryptographic fields.

## 7. Client persistence

Local SQLCipher tables (names already reserved):

| Table | Role |
|-------|------|
| `OmemoDevices` | Own IK/SPK/OPK private material |
| `OmemoDeviceList` | `profile_id → device_ids` |
| `OmemoRatchets` | Per `(peer_profile, peer_device)` session JSON |
| `OmemoTrustTable` | `device_id`, fingerprint, trust level (TOFU) |

Ratchet state MUST be persisted after every successful encrypt/decrypt. Never
reuse a stale in-memory state after persistence.

## 8. Out of scope

- Media CEK wrapping (#236)
- Sender Keys / groups (#237)
- Improved device discovery beyond `rid: "*"` (#235)
- Fingerprint verification UI
- Team/business mode (remains plaintext)
