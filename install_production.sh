#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer v1.0.57"
echo "==============================="
echo ""

# -----------------------------
# 基本設定
# -----------------------------
IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
HOST_PORT="${HOST_PORT:-3067}"
INTERNAL_DB_DIR="/opt/schedulerbot/db"

# -----------------------------
# 判斷是否為本地桌面
# -----------------------------
IS_LOCAL_DESKTOP=false

if [[ "${OSTYPE:-}" == darwin* ]]; then
  DB_DIR="${DB_DIR:-/Users/Shared/xtoolbot-db}"
  IS_LOCAL_DESKTOP=true
elif grep -qi microsoft /proc/version 2>/dev/null; then
  DB_DIR="${DB_DIR:-/mnt/c/Users/Public/xtoolbot-db}"
  IS_LOCAL_DESKTOP=true
elif [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == mingw* ]]; then
  DB_DIR="${DB_DIR:-/c/Users/Public/xtoolbot-db}"
  IS_LOCAL_DESKTOP=true
else
  DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
fi

CLEAN_ALL=false

# -----------------------------
# 解析參數
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v) VERSION="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --port) HOST_PORT="$2"; shift 2;;
    --db-dir) DB_DIR="$2"; shift 2;;
    --cleanup-all|--cleanup) CLEAN_ALL=true; shift 1;;
    --help|-h)
      echo "用法略…"; true;;
    *)
      echo "❌ 未知參數：$1"; true;;
  esac
done

FULL_IMAGE="$IMAGE:$VERSION"

echo "📌 Version:   $VERSION"
echo "📌 DB Path:   $DB_DIR"
echo "📌 Container: $CONTAINER_NAME"

# -----------------------------
# 檢查 Docker
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ 請先安裝 Docker"
  true
fi

echo "✔ docker 已安裝"

# -----------------------------
# 解析 Token
# -----------------------------
if [[ -n "$TOKEN" ]]; then
  echo "$TOKEN" | docker login ghcr.io -u $TOKEN --password-stdin 2>/dev/null || true
fi

# -----------------------------
# 拉取 Image
# -----------------------------
echo "📦 拉取 image：$FULL_IMAGE"
docker pull "$FULL_IMAGE" || true

# -----------------------------
# 建立目錄
# -----------------------------
mkdir -p "$DB_DIR"

# -----------------------------
# 判斷部署模式
# -----------------------------
if [[ "$IS_LOCAL_DESKTOP" == "true" ]]; then
  # ====== 本地桌面模式 ======
  echo "🖥 偵測到本地端電腦，啟動開發模式（docker run）"
  
  # 移除舊容器
  if [[ "$CLEAN_ALL" == "true" ]]; then
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  fi
  
  # 啟動容器
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
    
else
  # ====== Linux 伺服器模式 ======
  echo "🖥 偵測到 Linux 伺服器，啟動正式部署模式（docker-compose.prod.yml + Caddy）"
  
  cd /opt || true
  
  # 建立 docker-compose.prod.yml
  cat > docker-compose.prod.yml << EOF
version: "3.8"
services:
  schedulerbot:
    image: $FULL_IMAGE
    container_name: $CONTAINER_NAME
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
  schedulerbot-caddy:
    image: caddy:2
    container_name: schedulerbot-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
    network_mode: host
EOF

  # 建立 Caddyfile
  cat > Caddyfile {
    # 初始 HTTP 佔位，稍後用戶需手動修改為自己的網域
    :80 {
      respond "XtoolBot" 200
    }
  }

  # 移除舊容器
  docker compose -f docker-compose.prod.yml down 2>/dev/null || docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
  
  # 啟動
  docker compose -f docker-compose.prod.yml up -d || docker-compose -f docker-compose.prod.yml up -d
fi

# -----------------------------
# 完成
# -----------------------------
if [[ "$IS_LOCAL_DESKTOP" == "true" ]]; then
  echo ""
  echo "🎉 安裝完成！"
  echo "➡️  本地開啟： http://localhost:${HOST_PORT}"
  echo ""
else
  echo ""
  echo "🎉 部署完成（正式伺服器模式）"
  echo "🔗 之後請在 System Settings 裡設定 Server URL：你的域名（例如 https://mybot.xtoolbot.com）"
  echo ""
  echo "💡 首次登入請在瀏覽器開啟："
  echo " 👉 http://localhost:${HOST_PORT}"
  echo " （之後設定好網域與 HTTPS 後，請改用你的網域登入）"
  echo ""
fi

# ====== Host Upgrade Service (自動安裝) ======
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
sudo curl -sL https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-host.js -o /opt/xtoolbot-upgrade.js || true

# Start upgrade service
echo "🚀 Starting upgrade service..."
cd /opt || true
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
    sudo pm2 logs xtoolbot-upgrade --lines 5 --nostream || true
fi

echo ""
echo "======================================"
echo "✅ ALL DONE!"
echo "======================================"
