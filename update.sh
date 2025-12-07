#!/usr/bin/env bash
set -euo pipefail

# =========================
# SchedulerBot 更新腳本
# =========================

IMAGE_BASE="ghcr.io/gda-project-dev/schedulerbot"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"

HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
EXTRA_DOCKER_ARGS="${EXTRA_DOCKER_ARGS:-}"

VERSION="${SCHEDULERBOT_VERSION:-}"

# 🧷 內建 GHCR token（請改成你的真實 PAT）
#   也可以透過環境變數 GHCR_TOKEN 覆蓋
DEFAULT_GHCR_TOKEN="REPLACE_ME_WITH_REAL_GHCR_TOKEN"
TOKEN="${GHCR_TOKEN:-$DEFAULT_GHCR_TOKEN}"

# ----- 解析參數 -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="$2"
      shift 2
      ;;
    # 保留 --token 覆蓋用，雖然你現在是寫死在腳本裡
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --container-name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --host-port)
      HOST_PORT="$2"
      shift 2
      ;;
    --db-dir)
      DB_DIR="$2"
      shift 2
      ;;
    --extra-args)
      EXTRA_DOCKER_ARGS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<EOF
SchedulerBot 更新腳本

用法：
  bash update.sh --version 1.3.20

可選參數：
  --token YOUR_GHCR_PAT         覆蓋內建 GHCR token
  --container-name schedulerbot 更改容器名稱（預設：schedulerbot）
  --host-port 3067              更改對外 Port（預設：3067）
  --db-dir /opt/schedulerbot/db DB 目錄（目前只用來備份 sqlite）
  --extra-args "...docker args" 額外 docker run 參數
EOF
      exit 0
      ;;
    *)
      echo "未知參數: $1"
      echo "使用 --help 查看說明"
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "❌ 必須指定版本號，例如： bash update.sh --version 1.3.20"
  exit 1
fi

IMAGE_TAG="${IMAGE_BASE}:${VERSION}"

echo "========================================"
echo "🚀 更新 SchedulerBot"
echo "  Image:      ${IMAGE_TAG}"
echo "  Container:  ${CONTAINER_NAME}"
echo "  Host Port:  ${HOST_PORT}"
echo "  DB Dir:     ${DB_DIR}"
echo "  Extra Args: ${EXTRA_DOCKER_ARGS}"
echo "========================================"

# ----- Docker login（如提供 token）-----
if [[ -n "$TOKEN" && "$TOKEN" != "REPLACE_ME_WITH_REAL_GHCR_TOKEN" ]]; then
  echo "🔐 使用 GHCR token 登入 ghcr.io..."
  echo "$TOKEN" | docker login ghcr.io -u gda-project-dev --password-stdin
else
  echo "ℹ️ 未提供有效 GHCR token，假設這台機器已經登錄過 ghcr.io。"
fi

# ----- 確保 DB 目錄存在（目前只用來放 sqlite 檔備份，不再掛 volume）-----
if [[ ! -d "$DB_DIR" ]]; then
  echo "📁 建立 DB 目錄: $DB_DIR"
  mkdir -p "$DB_DIR"
fi

# ----- Pull 新版本 -----
echo "📦 拉取 image: ${IMAGE_TAG}"
docker pull "$IMAGE_TAG"

# ----- 停止並移除舊 container（如果存在） -----
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  echo "🛑 停止舊容器: ${CONTAINER_NAME}"
  docker stop "$CONTAINER_NAME" || true

  echo "🧹 移除舊容器: ${CONTAINER_NAME}"
  docker rm "$CONTAINER_NAME" || true
else
  echo "ℹ️ 找不到舊容器 ${CONTAINER_NAME}，跳過停止 / 移除步驟。"
fi

# ----- 啟動新版本 -----
echo "🐳 啟動新版本容器..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:3067" \
  --restart unless-stopped \
  $EXTRA_DOCKER_ARGS \
  "$IMAGE_TAG"

echo "✅ 更新完成！目前執行版本：${IMAGE_TAG}"
echo "➡️ 請在瀏覽器開啟： http://<這台伺服器IP>:${HOST_PORT}"
