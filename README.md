# CI/CD Pipeline with GitHub Actions, Docker and Nginx

[![ci-cd](https://github.com/Samarth9299/cicd-docker-nginx/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/Samarth9299/cicd-docker-nginx/actions/workflows/ci-cd.yml)

Every push to `main` is **tested, built into a Docker image, pushed to Docker Hub and deployed to an AWS EC2 instance** behind **Nginx** (reverse proxy with SSL termination). There are no manual deployment steps, and the same tested image goes from commit to production.

## Pipeline

```
 git push main
      │
      ▼
┌───────────┐   ┌─────────────────────┐   ┌──────────────────────────────┐
│   test    │──▶│     build-push      │──▶│            deploy            │
│ flake8    │   │ docker build        │   │ ssh EC2 → deploy-app <tag>   │
│ pytest    │   │ tag: <sha>, latest  │   │  docker pull, restart,       │
│ shellcheck│   │ push → Docker Hub   │   │  /health check, auto-rollback│
└───────────┘   └─────────────────────┘   │ smoke test through Nginx     │
                                          └──────────────────────────────┘

 EC2 (Ubuntu):  Internet ──▶ Nginx :80/:443 (Let's Encrypt SSL) ──▶ 127.0.0.1:8000 ──▶ app container
```

## What it demonstrates

| Area | Implementation |
|---|---|
| CI | Lint (flake8), unit tests (pytest) and ShellCheck on every push and pull request |
| Containerisation | Small `python:3.12-slim` image, dependency layer caching, non-root user, `HEALTHCHECK` |
| Artifact versioning | Each image is tagged with the short commit SHA (plus `latest`), so every release is traceable |
| CD | GitHub Actions deploys over SSH; build cache via GitHub Actions cache |
| Safe deploys | `deploy.sh` checks `/health` after starting the new container and **rolls back** to the previous image if it fails |
| Web server | Nginx reverse proxy, security headers, HTTP→HTTPS redirect, free SSL via Certbot |
| Security | Container bound to `127.0.0.1` only, SSH key and Docker Hub token stored as GitHub Secrets |

## Repository layout

```
app/
  app.py                 # Flask app: /, /health, /api/info
  requirements*.txt
  tests/test_app.py      # pytest unit tests
Dockerfile
docker-compose.yml       # run app + Nginx locally
nginx/
  app.conf               # production reverse-proxy config (EC2)
  local.conf             # local docker-compose config
scripts/
  setup-ec2.sh           # one-time server setup: Docker, Nginx, Certbot
  deploy.sh              # pull → replace → health check → rollback
.github/workflows/ci-cd.yml
```

## Run locally

```bash
# Option A: Python only
cd app && pip install -r requirements-dev.txt && pytest -q && python app.py
# open http://localhost:8000

# Option B: full stack with Docker (app + Nginx)
docker compose up --build
# open http://localhost:8080
```

## Deploy to AWS (one-time setup)

1. **Launch an EC2 instance**: Ubuntu 24.04, t2.micro/t3.micro. Its security group should allow 22 (SSH, from your IP only), 80 and 443.
2. **Copy the repo to the server and run the setup script**:
   ```bash
   git clone https://github.com/Samarth9299/cicd-docker-nginx.git
   cd cicd-docker-nginx
   sudo ./scripts/setup-ec2.sh                                  # HTTP only
   # or, if a domain's DNS A record points to the server:
   sudo ./scripts/setup-ec2.sh app.example.com you@example.com  # adds SSL
   ```
3. **Create a Docker Hub access token** (Docker Hub → Account settings → Personal access tokens).
4. **Add GitHub Secrets** (repo → Settings → Secrets and variables → Actions):

   | Secret | Value |
   |---|---|
   | `DOCKERHUB_USERNAME` | your Docker Hub username |
   | `DOCKERHUB_TOKEN` | the access token from step 3 |
   | `EC2_HOST` | EC2 public IP or domain |
   | `EC2_USER` | `ubuntu` |
   | `EC2_SSH_KEY` | contents of the private key (`.pem`) used to SSH into the instance |

5. **Push to `main`**. The pipeline tests, builds, pushes and deploys. Open `http://<EC2_HOST>/` and check `/api/info`: the commit shown matches your latest push.

## Rollback

Every image is kept on Docker Hub under its commit SHA. To go back manually:

```bash
ssh ubuntu@<EC2_HOST> "deploy-app <dockerhub-user>/cicd-demo <older-sha>"
```

## Known limitation

A single container is replaced in place, so there is a few-second gap while it restarts. Next step: run two containers behind an Nginx `upstream` (blue-green) for true zero-downtime deploys.
