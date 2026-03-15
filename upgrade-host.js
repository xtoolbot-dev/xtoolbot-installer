#!/usr/bin/env node
const http = require('http');
const { spawn } = require('child_process');

const PORT = 3068;

const server = http.createServer((req, res) => {
  console.log('[upgrade] Received request:', req.url);
  
  if (req.url === '/upgrade' && req.method === 'POST') {
    console.log('[upgrade] Starting upgrade on host...');
    
    // Run upgrade command on host
    const command = `
      docker stop schedulerbot schedulerbot-caddy 2>/dev/null || true
      docker rm schedulerbot schedulerbot-caddy 2>/dev/null || true
      curl -s https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/install_production.sh | sudo bash
    `;
    
    console.log('[upgrade] Running:', command);
    
    const child = spawn('bash', ['-c', command], {
      detached: true,
      stdio: 'ignore'
    });
    
    child.unref();
    
    console.log('[upgrade] Upgrade started, pid:', child.pid);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Upgrade started on host' }));
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
