#!/bin/bash
# Don't exit on error - continue to upgrade service
set -uo pipefail

echo "Running Docker installation..."

# Copy the original Docker install logic here (simplified)
# ... Docker install steps ...

echo "Done Docker. Continuing to upgrade service..."

# ====== Host Upgrade Service ======
echo "Installing host upgrade service..."

# Install Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    echo "Installing PM2..."
    sudo npm install -g pm2
fi

# Start upgrade service
echo "Starting upgrade service..."
curl -sL https://raw.githubusercontent.com/xtoolbot-dev/xtoolbot-installer/main/upgrade-host.js -o /opt/xtoolbot-upgrade.js
cd /opt
pm2 delete xtoolbot-upgrade 2>/dev/null || true
pm2 start /opt/xtoolbot-upgrade.js --name xtoolbot-upgrade
pm2 save

# Test
sleep 2
curl -s http://localhost:3068/health && echo " OK" || echo "Failed"
