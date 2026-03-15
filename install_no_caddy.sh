#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
FULL_IMAGE="${FULL_IMAGE:-gda3692/xtoolbot-client:latest}"

mkdir -p "$DB_DIR"

INSTALL_PATH="/opt/xtoolbot-server"
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

echo "📦 Creating docker-compose.prod.yml (no Caddy)..."

cat > docker-compose.prod.yml << 'COMPOSE'
version: "3.8"

services:
  schedulerbot:
    image: gda3692/xtoolbot-client:latest
    container_name: schedulerbot
    restart: unless-stopped
    ports:
      - "3067:3067"
    environment:
      - NODE_ENV=production
      - PORT=3067
      - DB_DIR=/opt/schedulerbot/db
    volumes:
      - /opt/schedulerbot/db:/opt/schedulerbot/db
      - /var/run/docker.sock:/var/run/docker.sock
COMPOSE

echo "🚀 Starting container..."
docker-compose -f docker-compose.prod.yml up -d

echo "✅ Done! Access at: http://localhost:3067"
