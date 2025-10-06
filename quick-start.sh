#!/bin/bash

# CTFd Quick Start Script untuk VPS
# Script ini akan setup CTFd dengan HTTPS di VPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CTFd VPS Quick Start                     ║"
echo "║                  Setup dengan HTTPS                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ Jangan jalankan script ini sebagai root!${NC}"
   echo "Gunakan: sudo -u username ./quick-start.sh"
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker installed! Please logout and login again.${NC}"
    exit 0
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Get domain and email
echo -e "${BLUE}🔧 Konfigurasi Domain dan Email${NC}"
echo "=================================="

read -p "🌐 Masukkan domain Anda (contoh: ctfd.example.com): " DOMAIN
read -p "📧 Masukkan email Anda untuk Let's Encrypt: " EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ Domain dan email harus diisi!${NC}"
    exit 1
fi

echo -e "${YELLOW}📝 Konfigurasi:${NC}"
echo "   Domain: $DOMAIN"
echo "   Email: $EMAIL"
echo ""

# Update configurations
echo -e "${YELLOW}🔧 Updating configurations...${NC}"

# Update nginx config
sed -i "s/your-domain.com/$DOMAIN/g" conf/nginx/https.conf

# Update docker-compose
sed -i "s/your-domain.com/$DOMAIN/g" docker-compose.https.yml
sed -i "s/your-email@example.com/$EMAIL/g" docker-compose.https.yml

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p certbot/www
mkdir -p .data/CTFd/logs
mkdir -p .data/CTFd/uploads
mkdir -p .data/mysql
mkdir -p .data/redis

# Setup firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Start services
echo -e "${YELLOW}🚀 Starting CTFd services...${NC}"
docker-compose -f docker-compose.https.yml up -d

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 30

# Generate SSL certificate
echo -e "${YELLOW}🔐 Generating SSL certificate...${NC}"
docker-compose -f docker-compose.https.yml run --rm certbot

# Restart nginx with SSL
echo -e "${YELLOW}🔄 Restarting nginx with SSL...${NC}"
docker-compose -f docker-compose.https.yml restart nginx

# Create renewal script
cat > renew-ssl.sh << 'EOF'
#!/bin/bash
echo "🔄 Renewing SSL certificates..."
docker-compose -f docker-compose.https.yml run --rm certbot renew
echo "🔄 Reloading nginx..."
docker-compose -f docker-compose.https.yml exec nginx nginx -s reload
echo "✅ Certificate renewal completed!"
EOF

chmod +x renew-ssl.sh

# Setup automatic renewal
echo -e "${YELLOW}⏰ Setting up automatic certificate renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 12 * * * $(pwd)/renew-ssl.sh >> $(pwd)/ssl-renewal.log 2>&1") | crontab -

# Create management script
cat > manage-ctfd.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Starting CTFd..."
        docker-compose -f docker-compose.https.yml up -d
        ;;
    stop)
        echo "🛑 Stopping CTFd..."
        docker-compose -f docker-compose.https.yml down
        ;;
    restart)
        echo "🔄 Restarting CTFd..."
        docker-compose -f docker-compose.https.yml restart
        ;;
    logs)
        echo "📋 Showing CTFd logs..."
        docker-compose -f docker-compose.https.yml logs -f
        ;;
    status)
        echo "📊 CTFd status:"
        docker-compose -f docker-compose.https.yml ps
        ;;
    update)
        echo "🔄 Updating CTFd..."
        git pull
        docker-compose -f docker-compose.https.yml build
        docker-compose -f docker-compose.https.yml up -d
        ;;
    backup)
        echo "💾 Creating backup..."
        DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="/backup/ctfd_$DATE"
        mkdir -p $BACKUP_DIR
        docker-compose -f docker-compose.https.yml exec -T db mysqldump -u ctfd -pctfd ctfd > $BACKUP_DIR/database.sql
        cp -r .data/CTFd/uploads $BACKUP_DIR/
        echo "✅ Backup created: $BACKUP_DIR"
        ;;
    *)
        echo "CTFd Management Script"
        echo "Usage: $0 {start|stop|restart|logs|status|update|backup}"
        echo ""
        echo "Commands:"
        echo "  start   - Start CTFd services"
        echo "  stop    - Stop CTFd services"
        echo "  restart - Restart CTFd services"
        echo "  logs    - Show CTFd logs"
        echo "  status  - Show service status"
        echo "  update  - Update CTFd to latest version"
        echo "  backup  - Create backup of database and uploads"
        ;;
esac
EOF

chmod +x manage-ctfd.sh

# Final status check
echo -e "${YELLOW}🔍 Checking service status...${NC}"
sleep 10
docker-compose -f docker-compose.https.yml ps

echo ""
echo -e "${GREEN}🎉 CTFd berhasil di-deploy!${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}🌐 Akses CTFd:${NC}"
echo "   HTTP:  http://$DOMAIN (redirect ke HTTPS)"
echo "   HTTPS: https://$DOMAIN"
echo ""
echo -e "${BLUE}🛠️  Manajemen CTFd:${NC}"
echo "   Start:   ./manage-ctfd.sh start"
echo "   Stop:    ./manage-ctfd.sh stop"
echo "   Restart: ./manage-ctfd.sh restart"
echo "   Logs:    ./manage-ctfd.sh logs"
echo "   Status:  ./manage-ctfd.sh status"
echo "   Update:  ./manage-ctfd.sh update"
echo "   Backup:  ./manage-ctfd.sh backup"
echo ""
echo -e "${BLUE}🔐 SSL Certificate:${NC}"
echo "   Manual renewal: ./renew-ssl.sh"
echo "   Auto renewal: Setiap hari jam 12:00 PM"
echo "   Renewal logs: tail -f ssl-renewal.log"
echo ""
echo -e "${YELLOW}📝 Catatan Penting:${NC}"
echo "1. Pastikan domain $DOMAIN mengarah ke IP VPS ini"
echo "2. SSL certificate akan otomatis diperbarui setiap hari"
echo "3. Backup database dan uploads secara berkala"
echo "4. Monitor logs untuk troubleshooting"
echo ""
echo -e "${GREEN}✅ Setup selesai! CTFd siap digunakan.${NC}"
