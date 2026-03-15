#!/usr/bin/env node
const http = require('http');
const { spawn } = require('child_process');

const PORT = 3068;

const server = http.createServer((req, res) => {
  console.log('[upgrade] Received request:', req.url, req.method);
  
  if (req.url === '/upgrade' && req.method === 'POST') {
    console.log('[upgrade] Starting upgrade on host...');
    
    // Simple upgrade: pull latest and restart
    const command = `
      docker pull gda3692/xtoolbot-client:latest
      docker stop schedulerbot 2>/dev/null || true
      docker rm schedulerbot 2>/dev/null || true
      docker run -d \
        --name schedulerbot \
        -p 3067:3067 \
        -e TZ=Asia/Taipei \
        -e NODE_ENV=production \
        -e PORT=3067 \
        -e DB_DIR=/opt/schedulerbot/db \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/schedulerbot/db:/opt/schedulerbot/db \
        --restart unless-stopped \
        gda3692/xtoolbot-client:latest
    `;
    
    console.log('[upgrade] Running upgrade command...');
    
    const child = spawn('bash', ['-c', command], {
      stdio: 'inherit'
    });
    
    child.on('close', (code) => {
      console.log('[upgrade] Upgrade completed with code:', code);
    });
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Upgrade started' }));
    return;
  }
  
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'host-upgrade-service' }));
    return;
  }
  
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log('[upgrade] Host upgrade service running on port', PORT);
});
