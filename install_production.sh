#!/usr/bin/env bash
# Version: 1.0.53 - 2026-03-15
set -uo pipefail

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer v1.0.53"
echo "==============================="
echo ""

IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
FULL_IMAGE="$IMAGE:$VERSION"

echo "📌 Version: $VERSION"
echo "📌 DB Path: $DB_DIR"
echo "📌 Container: $CONTAINER_NAME"

# Check if docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not installed"
    exit 1
fi

echo "✅ Docker installed"

# Pull image
echo "📦 Pulling image: $FULL_IMAGE"
docker pull "$FULL_IMAGE" || true

# Detect if Linux server or local desktop
if grep -qi linux /proc/version 2>/dev/null && [[ ! -d /Users ]]; then
    echo "🖥 Linux server mode"
    mkdir -p "$DB_DIR"
    cd /opt
    
    cat > docker-compose.yml << EOF
version: "3.8"
services:
  schedulerbot:
    image: $FULL_IMAGE
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$HOST_PORT:3067"
    environment:
      - NODE_ENV=production
      - PORT=3067
      - DB_DIR=/opt/schedulerbot/db
    volumes:
      - $DB_DIR:/opt/schedulerbot/db
      - /var/run/docker.sock:/var/run/docker.sock
EOF

    docker compose -f docker-compose.yml up -d || docker-compose -f docker-compose.yml up -d
    
else
    echo "🖥 Local desktop mode"
    mkdir -p "$DB_DIR"
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "${HOST_PORT}:3067" \
        -e TZ=Asia/Taipei \
        -e SERVER_URL="http://localhost:${HOST_PORT}" \
        -e DB_DIR="$DB_DIR" \
        -v "/var/run/docker.sock:/var/run/docker.sock" \
        -v "$DB_DIR:$DB_DIR" \
        --restart unless-stopped \
        "$FULL_IMAGE"
fi

echo ""
echo "✅ Installation complete!"
echo "➡️  Open: http://localhost:${HOST_PORT}"

# ====== Host Upgrade Service ======
echo ""
echo "Installing host upgrade service..."

# Install Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    echo "Installing PM2..."
    sudo npm install -g pm2
fi

# Start upgrade service
echo "Starting upgrade service..."
curl -sL https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-host.js -o /opt/xtoolbot-upgrade.js
cd /opt
pm2 delete xtoolbot-upgrade 2>/dev/null || true
pm2 start /opt/xtoolbot-upgrade.js --name xtoolbot-upgrade
pm2 save

# Test
sleep 2
curl -s http://localhost:3068/health && echo " ✅ Upgrade service OK" || echo " ⚠️ Upgrade service failed"
