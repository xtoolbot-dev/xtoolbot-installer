#!/usr/bin/env bash
# v1.0.58 - Robust installer with no exit on error

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer v1.0.58"
echo "==============================="
echo ""

# Don't exit on error - continue to upgrade service
set -uo pipefail

IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
FULL_IMAGE="$IMAGE:$VERSION"

echo "📌 Version: $VERSION"
echo "📌 DB Path: $DB_DIR"
echo "📌 Container: $CONTAINER_NAME"

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not installed"
    exit 1
fi
echo "✅ Docker installed"

# Pull image
echo "📦 Pulling image: $FULL_IMAGE"
docker pull "$FULL_IMAGE" || true

# Linux server mode
if grep -qi linux /proc/version 2>/dev/null && [[ ! -d /Users ]]; then
    echo "🖥 Linux server mode"
    
    mkdir -p "$DB_DIR"
    cd /opt || exit 1
    
    # Remove old containers
    docker stop schedulerbot schedulerbot-caddy 2>/dev/null || true
    docker rm schedulerbot schedulerbot-caddy 2>/dev/null || true
    
    # Create docker-compose
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
    volumes:
      - $DB_DIR:/opt/schedulerbot/db
      - /var/run/docker.sock:/var/run/docker.sock
EOF

    docker compose up -d || docker-compose up -d
    
    echo "✅ Container started"
fi

# ====== Host Upgrade Service ======
echo ""
echo "======================================"
echo "🚀 Installing host upgrade service..."
echo "======================================"

# Install Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - || true
    sudo apt-get install -y nodejs || true
fi
node -v && echo "✅ Node.js ready"

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    echo "📦 Installing PM2..."
    sudo npm install -g pm2 || true
fi
pm2 -v && echo "✅ PM2 ready"

# Download upgrade service
echo "📥 Downloading upgrade service..."
sudo curl -sL https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-host.js -o /opt/xtoolbot-upgrade.js || {
    echo "❌ Failed to download"
}

# Start upgrade service
echo "🚀 Starting upgrade service..."
cd /opt || exit 1
sudo pm2 delete xtoolbot-upgrade 2>/dev/null || true
sudo pm2 start /opt/xtoolbot-upgrade.js --name xtoolbot-upgrade || true
sudo pm2 save || true

# Test
sleep 3
echo "🔍 Testing upgrade service..."
if curl -s http://localhost:3068/health >/dev/null; then
    echo "✅ Upgrade service running on port 3068"
else
    echo "⚠️ Upgrade service not responding"
    echo "📋 Logs:"
    sudo pm2 logs xtoolbot-upgrade --lines 5 --nostream || true
fi

echo ""
echo "======================================"
echo "✅ ALL DONE!"
echo "======================================"
echo "🌐 Open: http://localhost:$HOST_PORT"
echo "🔧 Upgrade service: http://localhost:3068"
