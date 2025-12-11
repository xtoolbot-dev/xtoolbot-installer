#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer"
echo "==============================="
echo ""

# ---------------------------------------------------------
# 基本設定
# ---------------------------------------------------------
IMAGE="gda3692/xtoolbot-client"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"
VERSION="${SCHEDULERBOT_VERSION:-latest}"
TOKEN="${GHCR_TOKEN:-}"
HOST_PORT="${HOST_PORT:-3067}"
INTERNAL_DB_DIR="/opt/schedulerbot/db"

IS_LOCAL_DESKTOP=false

# ---------------------------------------------------------
# 判斷系統類型
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# 處理參數
# ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="$2"; shift 2 ;;
    --port)
      HOST_PORT="$2"; shift 2 ;;
    --db-dir)
      DB_DIR="$2"; shift 2 ;;
    --cleanup-all|--cleanup)
      CLEAN_ALL=true; shift ;;
    --help|-h)
      cat <<EOF
用法：
  curl -s https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/install_production.sh | sudo bash

參數：
  --version      Image 版本（預設 latest）
  --port         服務 port（預設 3067）
  --db-dir       DB 目錄
  --cleanup-all  清除所有 Docker 資源
EOF
      exit 0 ;;
    *)
      echo "❌ 未知參數：$1"; exit 1 ;;
  esac
done

FULL_IMAGE="$IMAGE:$VERSION"

echo ""
echo "📌 Version:   $VERSION"
echo "📌 DB Path:   $DB_DIR"
echo "📌 Container: $CONTAINER_NAME"
echo ""

# ---------------------------------------------------------
# 安裝 Docker
# ---------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 docker 未安裝，開始安裝..."
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable docker --now || true
else
  echo "✔ docker 已安裝"
fi

# ---------------------------------------------------------
# 清理舊 Docker
# ---------------------------------------------------------
if [[ "$CLEAN_ALL" == true ]]; then
  echo "🧹 清除所有舊 Docker 資源..."
  docker stop $(docker ps -q) || true
  docker rm $(docker ps -aq) || true
  docker system prune -af || true
  docker volume prune -f || true
fi

# ---------------------------------------------------------
# 判斷是否為真·Linux 伺服器
# ---------------------------------------------------------
IS_SERVER=false
if [[ "$IS_LOCAL_DESKTOP" == false ]]; then
  IS_SERVER=true
fi

# ---------------------------------------------------------
# 伺服器模式：使用 docker-compose.prod.yml + Caddy + HTTPS
# ---------------------------------------------------------
if [[ "$IS_SERVER" == true ]]; then
  echo "🖥 偵測到 Linux 伺服器，啟動正式部署模式（docker-compose.prod.yml + Caddy）"

  APP_DIR="/opt/xtoolbot-client"

  if [[ ! -d "$APP_DIR" ]]; then
    echo "📥 下載 xtoolbot-client 程式碼..."
    git clone https://github.com/xtoolbot-dev/xtoolbot-client.git "$APP_DIR"
  fi

  cd "$APP_DIR"

  echo "📦 拉取最新 image..."
  docker compose -f docker-compose.prod.yml pull || true

  echo "🐳 啟動 docker-compose.prod.yml（含 HTTPS）..."
  docker compose -f docker-compose.prod.yml up -d

  echo ""
  echo "🎉 部署完成！"
  echo "➡ 請把你的 domain 指向此伺服器 IP"
  echo "➡ Cloudflare 必須灰雲"
  echo "➡ 然後在 UI 裡填：https://your-bot-domain.com"
  echo ""
  exit 0
fi

# ---------------------------------------------------------
# 本地桌面模式 → 單容器直接跑
# ---------------------------------------------------------

echo "💻 偵測到本地環境（Mac / Windows / WSL），啟動單容器模式"

if [[ ! -d "$DB_DIR" ]]; then mkdir -p "$DB_DIR"; fi
chmod 777 "$DB_DIR" || true

docker pull "$FULL_IMAGE"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  docker stop "$CONTAINER_NAME" || true
  docker rm "$CONTAINER_NAME" || true
fi

SERVER_IP="localhost"
SERVER_URL="http://${SERVER_IP}:${HOST_PORT}"

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:3067" \
  -e TZ=Asia/Taipei \
  -e SERVER_URL="${SERVER_URL}" \
  -e DB_DIR="${INTERNAL_DB_DIR}" \
  -v "${DB_DIR}:${INTERNAL_DB_DIR}" \
  --restart unless-stopped \
  "$FULL_IMAGE"

echo ""
echo "🎉 已啟動 SchedulerBot！"
echo "➡ http://localhost:${HOST_PORT}"
echo ""
