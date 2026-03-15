# 在 install_production.sh 中添加升级服务

# 下载升级服务
curl -sL "https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-service.js" -o /opt/xtoolbot/upgrade-service.js

# 用 PM2 启动
cd /opt/xtoolbot
pm2 delete upgrade-service 2>/dev/null || true
pm2 start upgrade-service.js --name upgrade-service
pm2 save
