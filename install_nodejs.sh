#!/bin/bash
set -e

APP_DIR="/opt/xtoolbot"
PORT=3067
DB_DIR="$APP_DIR/db"

echo "========================================"
echo "🚀 XtoolBot 安装 (Node.js)"
echo "========================================"

# 安装 Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "📦 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "✅ Node.js 版本: $(node -v)"

# 创建目录
sudo mkdir -p "$DB_DIR"
cd "$APP_DIR"

# 克隆或更新代码
if [ -d ".git" ]; then
    echo "📥 更新代码..."
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

# 启动服务
echo "🚀 启动服务..."
sudo PORT=$PORT DB_DIR=$DB_DIR NODE_ENV=production npm start &

echo ""
echo "✅ 安装完成！"
echo "➡️  访问: http://localhost:$PORT"
