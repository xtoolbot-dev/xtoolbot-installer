#!/bin/bash
set -e

APP_DIR="/opt/xtoolbot"
PORT=3067
DB_DIR="$APP_DIR/db"
DOMAIN="${1:-localhost}"

echo "========================================"
echo "🚀 XtoolBot 安装 (Node.js + Caddy)"
echo "========================================"

# 安装 Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "📦 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "✅ Node.js 版本: $(node -v)"

# 安装 Caddy
if ! command -v caddy >/dev/null 2>&1; then
    echo "📦 安装 Caddy..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
fi

echo "✅ Caddy 已安装"

# 创建目录
sudo mkdir -p "$DB_DIR"
cd "$APP_DIR"

# 克隆或更新代码
if [ -d ".git" ]; then
    echo "📥 更新代码..."
    cd "$APP_DIR"
    sudo git pull
else
    echo "📥 下载代码..."
    sudo rm -rf "$APP_DIR"
    sudo git clone https://github.com/xtoolbot-dev/xtoolbot-client.git "$APP_DIR"
    cd "$APP_DIR"
fi

# 安装依赖
echo "📦 安装依赖..."
cd "$APP_DIR/social-scheduler-api"
sudo npm install --production

# 配置 Caddyfile
echo "📝 配置 Caddy..."
sudo tee /etc/caddy/Caddyfile > /dev/null <<CADDY
:$DOMAIN {
    reverse_proxy localhost:$PORT
    encode gzip
}
CADDY

# 启动服务
echo "🚀 启动服务..."
sudo pkill -f "node.*social-scheduler-api" 2>/dev/null || true
cd "$APP_DIR/social-scheduler-api"
sudo PORT=$PORT DB_DIR=$DB_DIR NODE_ENV=production nohup npm start > /tmp/xtoolbot.log 2>&1 &

# 重启 Caddy
sudo caddy reload --config /etc/caddy/Caddyfile

echo ""
echo "✅ 安装完成！"
echo "➡️  访问: http://$DOMAIN"
