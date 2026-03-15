#!/usr/bin/env node
const http = require('http');
const { exec, spawn } = require('child_process');

const PORT = 3068;

const server = http.createServer((req, res) => {
  console.log('[upgrade] Received request:', req.url);
  
  if (req.url === '/upgrade' && req.method === 'POST') {
    console.log('[upgrade] Starting upgrade...');
    
    const command = `
      docker stop schedulerbot schedulerbot-caddy 2>/dev/null || true
      docker rm schedulerbot schedulerbot-caddy 2>/dev/null || true
      docker pull gda3692/xtoolbot-client:latest
      docker run -d --name schedulerbot -p 3067:3067 -e NODE_ENV=production -e PORT=3067 -e DB_DIR=/opt/schedulerbot/db -v /opt/schedulerbot/db:/opt/schedulerbot/db -v /var/run/docker.sock:/var/run/docker.sock --restart unless-stopped gda3692/xtoolbot-client:latest
    `;
    
    console.log('[upgrade] Running command:', command);
    
    const child = spawn('bash', ['-c', command], {
      detached: true,
      stdio: 'ignore'
    });
    
    child.unref();
    
    console.log('[upgrade] Upgrade started, pid:', child.pid);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Upgrade started' }));
    return;
  }
  
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }
  
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log('[upgrade] Service running on port ' + PORT);
});
