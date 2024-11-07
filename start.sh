#!/bin/sh

if [ -z "$GIT_URL" ]; then
    echo "Error: No GIT_URL provided"
    exit 1
fi

rm -rf /var/www/html/*

echo "Cloneing $GIT_URL"
git clone "$GIT_URL" /tmp/website

mv /tmp/website/* /var/www/html/
rm -rf /tmp/website

echo "Finishing setup"
cat > /etc/nginx/http.d/default.conf << EOF
server {
    listen ${PORT};
    listen [::]:${PORT};
    
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

echo "Starting NGINX"
nginx -g "daemon off;"