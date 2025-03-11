#!/bin/sh


# Exit on error
set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    echo "Try: curl -s https://whatever.com/deploy.sh | sudo REPO_URL=\"https://github.com/username/repo.git\" sh"
    exit 1
fi

# Check if GitHub URL was provided via environment variable or as an argument
GITHUB_URL=${REPO_URL:-$1}
if [ -z "$GITHUB_URL" ]; then
    echo "Error: No GitHub repository URL provided!"
    echo "Usage options:"
    echo "  1. curl -s https://whatever.com/deploy.sh | REPO_URL=\"https://github.com/username/repo.git\" BRANCH=\"main\" sh"
    echo "  2. curl -s https://whatever.com/deploy.sh > deploy.sh && chmod +x deploy.sh && ./deploy.sh \"https://github.com/username/repo.git\" \"main\""
    exit 1
fi

# Set branch name from environment variable or argument, default to 'main'
BRANCH=${BRANCH:-${2:-main}}

# Set variables
TEMP_DIR="/tmp/website"
DEPLOY_DIR="/var/www/html"
NGINX_CONF="/etc/nginx/http.d/default.conf"

echo "==== Static Website Deployment ===="
echo "GitHub URL: $GITHUB_URL"
echo "Branch: $BRANCH"

# Install required packages
echo "\n[1/6] Installing required packages..."
apk update > /dev/null
apk add --no-cache git nginx > /dev/null

# Create necessary directories
mkdir -p "$DEPLOY_DIR"

# Remove temporary directory if it exists
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

# Clone the repository
echo "[2/6] Cloning the repository..."
git clone --branch "$BRANCH" --single-branch --depth 1 "$GITHUB_URL" "$TEMP_DIR" > /dev/null 2>&1

# Copy website files to deployment directory
echo "[3/6] Copying website files to $DEPLOY_DIR..."
rm -rf "$DEPLOY_DIR"/*
cp -r "$TEMP_DIR"/* "$DEPLOY_DIR"/

# Set correct permissions
echo "[4/6] Setting permissions..."
chown -R nginx:nginx "$DEPLOY_DIR"
chmod -R 755 "$DEPLOY_DIR"

# Create Nginx configuration if it doesn't exist
if [ ! -f "$NGINX_CONF" ]; then
    echo "[5/6] Creating Nginx configuration..."
    cat > "$NGINX_CONF" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
fi

# Start and enable Nginx
echo "[6/6] Starting Nginx..."
rc-update add nginx default > /dev/null 2>&1
rc-service nginx restart > /dev/null 2>&1 || rc-service nginx start > /dev/null 2>&1

# Clean up
rm -rf "$TEMP_DIR"

# Check if Nginx is running
if pgrep nginx > /dev/null; then
    echo "\n✅ Deployment successful!"
    echo "Your website should now be available at http://$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -n 1)"
    echo "======================================"
else
    echo "\n❌ Deployment failed! Nginx is not running."
    echo "Check logs with: cat /var/log/nginx/error.log"
    echo "======================================"
    exit 1
fi