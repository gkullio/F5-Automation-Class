#!/bin/bash
set -euo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/myapp-init.log
}
trap 'log "FAILED at line $LINENO with exit code $?"' ERR

# ── System packages ──────────────────────────────────────────────
sudo apt update -y || true
sudo apt upgrade -y || true
sudo apt-get install -y net-tools curl unzip git || true

log "System packages installed"

# ── Docker installation ──────────────────────────────────────────
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo service docker start
sudo usermod -a -G docker gage

log "Docker installed"

# ── NGINX Plus credentials ───────────────────────────────────────
sudo mkdir -p /etc/ssl/nginx

echo "${jwt_token}" | sudo tee /etc/ssl/nginx/license.jwt > /dev/null
echo "${ssl_cert}"  | sudo tee /etc/ssl/nginx/nginx-repo.crt > /dev/null
echo "${ssl_key}"   | sudo tee /etc/ssl/nginx/nginx-repo.key > /dev/null
sudo chmod 0644 /etc/ssl/nginx/license.jwt /etc/ssl/nginx/nginx-repo.crt /etc/ssl/nginx/nginx-repo.key

log "NGINX credentials written"

# ── NGINX Plus repository ────────────────────────────────────────
sudo apt install -y apt-transport-https lsb-release ca-certificates wget gnupg2 ubuntu-keyring

sudo wget -qO - https://cs.nginx.com/static/keys/nginx_signing.key \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null


printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" \
| sudo tee /etc/apt/sources.list.d/nginx-plus.list

sudo wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

# Create apt configuration for NGINX-Agent
echo Acquire::https::pkgs.nginx.com::Verify-Peer "true"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::Verify-Host "true"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::SslCert     "/etc/ssl/nginx/nginx-repo.crt"; >> /etc/apt/apt.conf.d/90pkgs-nginx
echo Acquire::https::pkgs.nginx.com::SslKey      "/etc/ssl/nginx/nginx-repo.key"; >> /etc/apt/apt.conf.d/90pkgs-nginx

# Add NGINX-Agent repository
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/nginx-agent/ubuntu/ `lsb_release -cs` agent" \
  | sudo tee /etc/apt/sources.list.d/nginx-agent.list


# ── App Protect repository ───────────────────────────────────────
wget -qO - https://cs.nginx.com/static/keys/app-protect-security-updates.key | \
gpg --dearmor | sudo tee /usr/share/keyrings/app-protect-security-updates.gpg > /dev/null

printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://pkgs.nginx.com/app-protect/ubuntu `lsb_release -cs` nginx-plus\n" | \
sudo tee /etc/apt/sources.list.d/nginx-app-protect.list

printf "deb [signed-by=/usr/share/keyrings/app-protect-security-updates.gpg] \
https://pkgs.nginx.com/app-protect-security-updates/ubuntu `lsb_release -cs` nginx-plus\n" | \
sudo tee /etc/apt/sources.list.d/app-protect-security-updates.list

# ── Install NGINX Plus and App Protect ───────────────────────────
sudo apt-get update -y
sudo apt install -y nginx-plus
sudo apt-get install -y app-protect

sudo cp /etc/ssl/nginx/license.jwt /etc/nginx/license.jwt

log "NGINX Plus and App Protect installed"

# Copy api.conf file
echo "${api_conf}" | sudo tee /etc/nginx/conf.d/api.conf > /dev/null

sudo systemctl enable nginx && sudo systemctl start nginx

ping -c 5 127.0.0.1
sudo curl https://agent.connect.nginx.com/nginx-agent/install | DATA_PLANE_KEY="${dp_token}" sh -s -- -y >> /var/log/myapp-init.log 2>&1

log "NGINX configured"


# Install spa-demo-app 
mkdir /etc/nginx/spa-demo-app
git init ~/spa-demo-app
cd ~/spa-demo-app
git remote add origin "https://github.com/gkullio/spa-demo-app.git"
git fetch origin main
git checkout main

mv ~/spa-demo-app /etc/nginx/spa-demo-app
# Deploy spa-demo-app using Docker Compose
sudo docker compose -f /etc/nginx/spa-demo-app/spa-demo-app/docker-compose.yml up -d

# Include the spa-app.conf in NGINX configuration to /etc/nginx/conf.d/
echo "${spa_conf}" | sudo tee /etc/nginx/conf.d/spa-app.conf > /dev/null  

# Swap out the proxy_set_header line with the proper one "proxy_set_header Host $host"
sudo sed -i 's/.*proxy_set_header.*/    proxy_set_header Host $host;/' /etc/nginx/conf.d/spa-app.conf

# rename the default.conf to remove it from being processed by NGINX
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak

# create a new directory to store the proxy_set_header snippets
sudo mkdir -p /etc/nginx/snippets
sudo tee /etc/nginx/snippets/proxy-headers.conf > /dev/null << 'EOF'
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
EOF

log "NGINX and SPA App configured"

# ── Start NGINX ──────────────────────────────────────────────────
sudo systemctl enable nginx
sudo nginx -t && sudo systemctl start nginx

log "NGINX started"

# ── Install Certbot and Generate TLS Cert ────────────────────────
sudo apt-get install certbot python3-certbot-nginx -y
sudo certbot --nginx \
  -d nginx.kulland.info \
  --non-interactive \
  --agree-tos \
  --no-eff-email \
  --email ${le_email} \
  --redirect

log "Certbot complete"

log "End of Line, Man."