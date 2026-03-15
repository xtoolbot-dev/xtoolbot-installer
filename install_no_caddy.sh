#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🚀 SchedulerBot Installer (No Caddy)"
echo "==============================="

IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
HOST_PORT="${HOST_PORT:-3067}"
INTERNAL_DB_DIR="/opt/schedulerbot/db"

mkdir -p "$INTERNAL_DB_DIR"

echo "📦 Pulling image..."
docker pull "${IMAGE}:${VERSION}" || true

INSTALL_PATH="/opt/xtoolbot-server"
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

echo "📥 Creating docker-compose.yml..."
cat > docker-compose.yml << EOF
version: "3.8"
services:
  schedulerbot:
    image: ${IMAGE}:${VERSION}
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${HOST_PORT}:3067"
    environment:
      - NODE_ENV=production
      - PORT=3067
      - DB_DIR=${INTERNAL_DB_DIR}
    volumes:
      - ${INTERNAL_DB_DIR}:${INTERNAL_DB_DIR}
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo "🚀 Starting container..."
docker compose -f docker-compose.yml up -d || docker-compose -f docker-compose.yml up -d

echo "✅ Done! Access at: http://localhost:${HOST_PORT}"
