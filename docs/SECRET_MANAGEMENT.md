# Secret management

Hardcoded secrets must not live in version control. Local Docker and production both load secrets from the environment (or a secret manager that injects env vars).

## Local development

1. Copy the example file: `cp .env.example .env`
2. Fill every required value (compose uses `${VAR:?…}` and will refuse to start if missing):
   - `SECRET_KEY_BASE` — `openssl rand -base64 64`
   - `SERVER_STATIC_KEY` — `openssl rand -base64 32`
   - `POSTGRES_PASSWORD`
   - `GF_SECURITY_ADMIN_PASSWORD`
   - `ZO_ROOT_USER_PASSWORD`
3. Optionally set `OTP_HMAC_SECRET` (`openssl rand -base64 32`). If unset, the backend falls back to `SECRET_KEY_BASE`.
4. Start the stack: `docker compose up -d`

`.env` is gitignored. Never commit real credentials.

## Production

| Secret | Used for | Source |
| --- | --- | --- |
| `SECRET_KEY_BASE` | Phoenix cookie + Guardian JWT signing | Required env / secret store |
| `OTP_HMAC_SECRET` | HMAC of OTP codes at rest | Preferred dedicated secret; falls back to `SECRET_KEY_BASE` |
| `SERVER_STATIC_KEY` | Rust Noise gateway identity | Required env / secret store |
| `POSTGRES_PASSWORD` | Database auth | Required env / secret store |
| `NOISE_STATIC_KEY` / `NOISE_STATIC_KEY_SECRET_ID` | Elixir Noise static key | Env, or AWS Secrets Manager via existing runtime hooks |

### Recommended store

Prefer a managed secret store over long-lived plaintext env files on disk:

1. **AWS Secrets Manager** / **SSM Parameter Store** — already partially wired for Noise static keys (`NOISE_STATIC_KEY_SECRET_*`).
2. **HashiCorp Vault** — inject at deploy time (Kubernetes CSI / Vault Agent / Terraform).
3. **Platform secrets** (Fly.io / Railway / ECS task secrets) — map 1:1 to the env vars above.

Rotate `SECRET_KEY_BASE` and `SERVER_STATIC_KEY` carefully: JWT and Noise sessions become invalid after rotation. Plan dual-key or maintenance windows when rotating.

## Checklist

- [ ] No plaintext production secrets in `docker-compose*.yml`, `*.exs`, or docs
- [ ] Deploy pipeline injects secrets; images do not bake them in
- [ ] `.env.example` lists every required variable with generation hints
- [ ] Access to the secret store is least-privilege and audited
