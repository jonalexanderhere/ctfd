#!/bin/bash

# CTFd HTTPS Setup Script
# This script sets up SSL certificates and configures CTFd for HTTPS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=""
EMAIL=""
NGINX_CONF="conf/nginx/https.conf"

echo -e "${GREEN}CTFd HTTPS Setup Script${NC}"
echo "=========================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root${NC}"
   exit 1
fi

# Get domain name
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain name (e.g., ctfd.example.com): " DOMAIN
fi

# Get email for Let's Encrypt
if [ -z "$EMAIL" ]; then
    read -p "Enter your email address for Let's Encrypt: " EMAIL
fi

echo -e "${YELLOW}Setting up SSL for domain: $DOMAIN${NC}"

# Create necessary directories
echo "Creating directories..."
mkdir -p certbot/www
mkdir -p .data/CTFd/logs
mkdir -p .data/CTFd/uploads
mkdir -p .data/mysql
mkdir -p .data/redis

# Update nginx configuration with domain
echo "Updating nginx configuration..."
sed -i "s/your-domain.com/$DOMAIN/g" $NGINX_CONF

# Update docker-compose with domain and email
echo "Updating docker-compose configuration..."
sed -i "s/your-domain.com/$DOMAIN/g" docker-compose.https.yml
sed -i "s/your-email@example.com/$EMAIL/g" docker-compose.https.yml

# Create initial nginx config for certificate generation
echo "Creating temporary nginx config for certificate generation..."
cat > conf/nginx/temp.conf << EOF
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name $DOMAIN;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Start temporary nginx for certificate generation
echo "Starting temporary nginx for certificate generation..."
docker-compose -f docker-compose.https.yml up -d nginx

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
sleep 10

# Generate SSL certificate
echo "Generating SSL certificate..."
docker-compose -f docker-compose.https.yml run --rm certbot

# Stop temporary nginx
echo "Stopping temporary nginx..."
docker-compose -f docker-compose.https.yml down

# Start full stack with HTTPS
echo "Starting CTFd with HTTPS..."
docker-compose -f docker-compose.https.yml up -d

# Create certificate renewal script
echo "Creating certificate renewal script..."
cat > renew-ssl.sh << 'EOF'
#!/bin/bash
# Certificate renewal script

echo "Renewing SSL certificates..."
docker-compose -f docker-compose.https.yml run --rm certbot renew

echo "Reloading nginx..."
docker-compose -f docker-compose.https.yml exec nginx nginx -s reload

echo "Certificate renewal completed!"
EOF

chmod +x renew-ssl.sh

# Setup cron job for automatic renewal
echo "Setting up automatic certificate renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * $(pwd)/renew-ssl.sh >> $(pwd)/ssl-renewal.log 2>&1") | crontab -

echo -e "${GREEN}Setup completed successfully!${NC}"
echo ""
echo "Your CTFd instance is now available at:"
echo "  HTTP:  http://$DOMAIN (redirects to HTTPS)"
echo "  HTTPS: https://$DOMAIN"
echo ""
echo "To manage your CTFd instance:"
echo "  Start:   docker-compose -f docker-compose.https.yml up -d"
echo "  Stop:    docker-compose -f docker-compose.https.yml down"
echo "  Logs:    docker-compose -f docker-compose.https.yml logs -f"
echo "  Renew:   ./renew-ssl.sh"
echo ""
echo "SSL certificates will be automatically renewed every day at 12:00 PM"
echo "Check renewal logs: tail -f ssl-renewal.log"
