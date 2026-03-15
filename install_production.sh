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
