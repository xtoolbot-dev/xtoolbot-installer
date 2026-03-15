#!/usr/bin/env node
const http = require('http');
const { exec } = require('child_process');

const PORT = 3068;

const server = http.createServer((req, res) => {
  if (req.url === '/upgrade' && req.method === 'POST') {
    console.log('Received upgrade request');
    
    const command = `
      docker stop schedulerbot schedulerbot-caddy 2>/dev/null
      docker rm schedulerbot schedulerbot-caddy 2>/dev/null
      curl -s https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/install_production.sh | sudo bash
    `;
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error('Upgrade error:', error.message);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: error.message }));
        return;
      }
      console.log('Upgrade started');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, message: 'Upgrade started' }));
    });
    return;
  }
  
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`Upgrade service running on port ${PORT}`);
});
