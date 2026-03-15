#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer"
echo "==============================="
echo ""

# -----------------------------
# 基本設定（保留你的原始設定）
# -----------------------------
IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
TOKEN="${GHCR_TOKEN:-}"
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
# 解析參數（保留你的邏輯）
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v) VERSION="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --port) HOST_PORT="$2"; shift 2;;
    --db-dir) DB_DIR="$2"; shift 2;;
    --cleanup-all|--cleanup) CLEAN_ALL=true; shift 1;;
    --help|-h)
      echo "用法略…"; exit 0;;
    *)
      echo "❌ 未知參數：$1"; exit 1;;
  esac
done

FULL_IMAGE="$IMAGE:$VERSION"

echo "📌 Version:   $VERSION"
echo "📌 DB Path:   $DB_DIR"
echo "📌 Container: $CONTAINER_NAME"
echo ""

# -----------------------------
# 安裝 Docker（保留）
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 未找到 docker，開始安裝..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker --now || true
  else
    echo "❌ 請先手動安裝 Docker"; exit 1
  fi
else
  echo "✔ docker 已安裝"
fi

# -----------------------------
# 準備 DB 目錄
# -----------------------------
mkdir -p "$DB_DIR"
chmod 777 "$DB_DIR"

# -----------------------------
# 拉 image
# -----------------------------
echo "📦 拉取 image：$FULL_IMAGE"
docker pull "$FULL_IMAGE"

# -----------------------------
# 偵測是否為 Linux 伺服器
# -----------------------------
if [[ "$IS_LOCAL_DESKTOP" == false ]]; then
  echo "🖥 偵測到 Linux 伺服器，啟動正式部署模式（docker-compose.prod.yml + Caddy）"

  INSTALL_PATH="/opt/xtoolbot-server"
  mkdir -p "$INSTALL_PATH"
  cd "$INSTALL_PATH"

  echo "📥 建立 docker-compose.prod.yml…"
  cat > docker-compose.prod.yml <<EOF
version: "3.8"

services:
  schedulerbot:
    image: ${FULL_IMAGE}
    container_name: schedulerbot
    restart: unless-stopped
    ports:
      - "3067:3067"           # ⭐ 對外開 3067，當保底入口
    environment:
      - NODE_ENV=production
      - PORT=3067
      - TZ=Asia/Taipei
      - DB_DIR=${INTERNAL_DB_DIR}
      - CADDYFILE_PATH=/opt/xtoolbot-server/Caddyfile
      - CADDY_ADMIN_URL=http://schedulerbot-caddy:2019/load
    volumes:
      - ${DB_DIR}:${INTERNAL_DB_DIR}
      - /var/run/docker.sock:/var/run/docker.sock
      - ./Caddyfile:/opt/xtoolbot-server/Caddyfile

  schedulerbot-caddy:
    image: caddy:2-alpine
    container_name: schedulerbot-caddy
    restart: unless-stopped
    command: ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile", "--watch"]
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - schedulerbot
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
EOF

  echo "📥 建立 Caddyfile（初始 HTTP 佔位，不轉發到 app）…"
  cat > Caddyfile <<EOF
:80 {
  respond "SchedulerBot is installed. Please open http://{host}:3067 to configure domain." 200
}
EOF
  # ⭐ 上面這裡是關鍵修改：
  #   - 不再 reverse_proxy 到 schedulerbot
  #   - 只是回一行提示文字
  #   這樣 http://IP 不是正式入口，真正入口是 http://IP:3067

  # 🔥 如果本機已經有舊的 schedulerbot / schedulerbot-caddy，就先砍掉
  if docker ps -a --format '{{.Names}}' | grep -q '^schedulerbot$'; then
    echo "🧹 發現舊的 schedulerbot 容器，先移除..."
    docker rm -f schedulerbot || true
  fi

  if docker ps -a --format '{{.Names}}' | grep -q '^schedulerbot-caddy$'; then
    echo "🧹 發現舊的 schedulerbot-caddy 容器，先移除..."
    docker rm -f schedulerbot-caddy || true
  fi

  echo "🚀 啟動正式部署 docker-compose.prod.yml…"

  # ✅ 1. 先試 docker compose（plugin 方式）
  if docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.prod.yml up -d

  # ✅ 2. 再試舊的 docker-compose binary
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose.prod.yml up -d

  # ✅ 3. 兩個都沒有，嘗試用 apt 安裝（先 plugin，再舊版）
  elif command -v apt-get >/dev/null 2>&1; then
    echo "🔧 找不到 docker compose / docker-compose，嘗試安裝 docker-compose-plugin 或 docker-compose..."

    apt-get update -y

    if apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
      echo "✔ 安裝 docker-compose-plugin 成功，使用 docker compose 啟動服務..."
      docker compose version >/dev/null 2>&1 || { echo "❌ docker compose 仍不可用"; exit 1; }
      docker compose -f docker-compose.prod.yml up -d
    elif apt-get install -y docker-compose >/dev/null 2>&1; then
      echo "✔ 安裝 docker-compose 成功，使用 docker-compose 啟動服務..."
      docker-compose -f docker-compose.prod.yml up -d
    else
      echo "❌ 無法透過 apt 安裝 docker-compose-plugin 或 docker-compose。"
      echo "   請手動安裝 compose 後再執行本安裝腳本。"
      exit 1
    fi
  else
    echo "❌ 找不到 'docker compose' 或 'docker-compose'，且系統沒有 apt-get 可安裝插件。"
    exit 1
  fi

  echo ""
  echo "🎉 部署完成（正式伺服器模式）"
  echo "🔗 之後請在 System Settings 裡設定 Server URL：你的域名（例如 https://mybot.xtoolbot.com）"

  # ⭐ 這裡也改一下提示，加上 :3067
  PUBLIC_IP=$(curl -s https://api.ipify.org || echo "")
  if [[ -n "$PUBLIC_IP" ]]; then
    echo ""
    echo "💡 首次登入請在瀏覽器開啟："
    echo "   👉 http://$PUBLIC_IP:3067"
    echo "   （之後設定好網域與 HTTPS 後，請改用你的網域登入）"
  fi

  echo ""
  exit 0
fi

# -----------------------------
# 本地 dev 模式（保持原邏輯）
# -----------------------------
echo "🧪 本地桌面環境（dev 模式），啟動 docker run"

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:3067" \
  -e TZ=Asia/Taipei \
  -e SERVER_URL="http://localhost:${HOST_PORT}" \
  -e DB_DIR="${INTERNAL_DB_DIR}" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "${DB_DIR}:${INTERNAL_DB_DIR}" \
  --restart unless-stopped \
  "$FULL_IMAGE"

echo ""
echo "🎉 安裝完成！"
echo "➡ 本地開啟： http://localhost:${HOST_PORT}"
echo ""

# ====== 升级服务 (Docker 容器内运行) ======
echo "📦 安装升级服务到容器..."

# 下载升级服务脚本
curl -sL "https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-service-docker.js" -o /tmp/upgrade-service.js 2>&1 || echo "下载失败: $?"

echo "📦 复制升级服务到容器..."
docker cp /tmp/upgrade-service.js schedulerbot:/app/upgrade-service.js 2>&1 || echo "复制失败: $?"

echo "📦 在容器内启动升级服务..."
docker exec schedulerbot node /app/upgrade-service.js > /tmp/upgrade.log 2>&1 &

echo "✅ 升级服务已安装 (端口 3068)"
