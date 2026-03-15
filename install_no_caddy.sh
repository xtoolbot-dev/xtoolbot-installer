#!/bin/bash
set -e

docker stop schedulerbot 2>/dev/null || true
docker rm schedulerbot 2>/dev/null || true

docker run -d \
  --name schedulerbot \
  -p 3067:3067 \
  -e NODE_ENV=production \
  -e PORT=3067 \
  -e DB_DIR=/opt/schedulerbot/db \
  -v /opt/schedulerbot/db:/opt/schedulerbot/db \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --restart unless-stopped \
  gda3692/xtoolbot-client:latest

echo "✅ Done! Access at: http://localhost:3067"
