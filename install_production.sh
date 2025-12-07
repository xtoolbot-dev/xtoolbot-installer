#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "==============================="
echo "🚀 SchedulerBot Installer"
echo "==============================="
echo ""

IMAGE="ghcr.io/gda-project-dev/schedulerbot"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"

# 預設版本，可用 --version 覆蓋（⚠️ 記得改成你實際最新版本）
VERSION="${SCHEDULERBOT_VERSION:-1.2.9}"

# GHCR token（private image 時用）
TOKEN="${GHCR_TOKEN:-}"

# 對外 port & DB 路徑
HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"

# 是否清掉所有舊 Docker 資源（容器 / image / volume …）
CLEAN_ALL=false

# ---------- 解析參數 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --port)
      HOST_PORT="$2"
      shift 2
      ;;
    --db-dir)
      DB_DIR="$2"
      shift 2
      ;;
    --cleanup-all|--cleanup)
      CLEAN_ALL=true
      shift 1
      ;;
    --help|-h)
      cat <<EOF
用法：

  # 最簡單（public image 或已經登入 ghcr.io）
  curl -s https://raw.githubusercontent.com/gda-project-dev/schedulerbot/main/install_production.sh \\
    | sudo bash -s -- --version ${VERSION}

  # 如果 image 是 private，需要 token：
  curl -s https://raw.githubusercontent.com/gda-project-dev/schedulerbot/main/install_production.sh \\
    | sudo bash -s -- --version ${VERSION} --token YOUR_GHCR_PAT

  # 如果這台機器之前跑過其他 Docker 專案，想全部清掉再裝：
  curl -s https://raw.githubusercontent.com/gda-project-dev/schedulerbot/main/install_production.sh \\
    | sudo bash -s -- --version ${VERSION} --cleanup-all

可選參數：
  --version / -v   指定要安裝的 image 版本（預設 ${VERSION}）
  --token          GHCR PAT，用於 private image 登入
  --port           對外埠號（預設 3067）
  --db-dir         DB 目錄（預設 /opt/schedulerbot/db）
  --cleanup-all    ⚠️ 停止並刪除所有 Docker 容器 / 不用的 image / volume
EOF
      exit 0
      ;;
    *)
      echo "❌ 未知參數：$1"
      exit 1
      ;;
  esac
done

FULL_IMAGE="$IMAGE:$VERSION"

echo "📌 Version:         $VERSION"
echo "📌 Container Name:  $CONTAINER_NAME"
echo "📌 Port:            $HOST_PORT"
echo "📌 DB Path:         $DB_DIR"
echo "📌 Cleanup All:     $CLEAN_ALL"
echo ""

# ---------- 安裝 Docker（如果還沒裝） ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 未找到 docker，開始安裝..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable docker --now || true
  else
    echo "❌ 找不到 apt-get，請先手動安裝 Docker 後再執行本腳本。"
    exit 1
  fi
else
  echo "✔ Docker 已安裝。"
fi

# ----------（選用）清理舊 Docker 資源 ----------
if [[ "$CLEAN_ALL" == true ]]; then
  echo ""
  echo "⚠️ 啟動『全部清理』模式：會停止並移除所有 Docker 容器、清除不用的 image / volume。"
  echo "   如果這台機器上有其他專案在用 Docker，請不要加 --cleanup-all。"
  echo ""

  if [ -n "$(docker ps -q)" ]; then
    echo "🛑 停止所有容器..."
    docker stop $(docker ps -q) || true
  fi

  if [ -n "$(docker ps -aq)" ]; then
    echo "🧹 移除所有容器..."
    docker rm $(docker ps -aq) || true
  fi

  echo "🧼 docker system prune -a ..."
  docker system prune -af || true

  echo "🧽 docker volume prune ..."
  docker volume prune -f || true

  echo "✅ Docker 舊資源已清理完畢。"
  echo ""
fi

# ---------- GHCR 登入（如有提供 token） ----------
if [[ -n "$TOKEN" ]]; then
  echo "🔐 使用 GHCR token 登入 ghcr.io..."
  echo "$TOKEN" | docker login ghcr.io -u gda-project-dev --password-stdin
else
  echo "ℹ️ 未提供 --token，假設 image 為 public 或已事先登入 ghcr.io。"
fi

# ---------- 準備 DB 目錄 ----------
if [[ ! -d "$DB_DIR" ]]; then
  echo "📁 建立 DB 目錄：$DB_DIR"
  mkdir -p "$DB_DIR"
fi

# ---------- 拉 image ----------
echo "📦 拉取 image：$FULL_IMAGE"
docker pull "$FULL_IMAGE"

# ---------- 停舊容器（同名） ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  echo "🛑 停止舊容器 ${CONTAINER_NAME}..."
  docker stop "$CONTAINER_NAME" || true
  echo "🧹 移除舊容器 ${CONTAINER_NAME}..."
  docker rm "$CONTAINER_NAME" || true
fi

# ---------- 計算主機 IP，給 SERVER_URL 用 ----------
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_URL="http://${SERVER_IP}:${HOST_PORT}"
echo "🌐 SERVER_URL 將設為：${SERVER_URL}"

# ---------- 跑新容器 ----------
echo "🐳 啟動 SchedulerBot 容器..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:3067" \
  -e TZ=Asia/Taipei \
  -e SERVER_URL="${SERVER_URL}" \
  --restart unless-stopped \
  "$FULL_IMAGE"

echo ""
echo "🎉 安裝完成！"
echo "➡ 請在瀏覽器打開：http://${SERVER_IP}:${HOST_PORT}"
echo ""
