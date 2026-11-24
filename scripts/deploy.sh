#!/usr/bin/env bash
# Runs ON the EC2 host (installed as /usr/local/bin/deploy-app).
# Pulls an image, replaces the running container, verifies /health and
# rolls back to the previous image automatically if the new one is unhealthy.
#
# Usage: deploy-app <image> <tag>
#   e.g. deploy-app yourname/cicd-demo 3f2c1ab
set -euo pipefail

IMAGE="${1:?image name required, e.g. yourname/cicd-demo}"
TAG="${2:?image tag required, e.g. a git commit SHA}"
NAME="cicd-demo"
PORT="8000"

# Remember what is running now, for rollback
PREVIOUS="$(docker inspect --format '{{.Config.Image}}' "$NAME" 2>/dev/null || true)"

echo "==> Pulling $IMAGE:$TAG"
docker pull "$IMAGE:$TAG"

run_container() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # Bind to localhost only: Nginx is the public entry point
  docker run -d --name "$NAME" --restart unless-stopped \
    -p "127.0.0.1:${PORT}:8000" "$1"
}

healthy() {
  for _ in $(seq 1 15); do
    if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "==> Starting $IMAGE:$TAG"
run_container "$IMAGE:$TAG"

if healthy; then
  echo "==> Deploy OK: $IMAGE:$TAG is healthy"
  docker image prune -f >/dev/null
  exit 0
fi

echo "!! New container failed its health check" >&2
docker logs --tail 50 "$NAME" >&2 || true

if [[ -n "$PREVIOUS" ]]; then
  echo "==> Rolling back to $PREVIOUS" >&2
  run_container "$PREVIOUS"
  healthy && echo "==> Rollback OK" >&2
fi
exit 1
