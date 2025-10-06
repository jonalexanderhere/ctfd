#!/bin/bash

# CTFd IP-Only Setup Script
# Script sederhana untuk setup CTFd dengan IP address dan HTTPS self-signed

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                CTFd IP-Only Quick Setup                     ║"
echo "║              Menggunakan IP Address + HTTPS                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ Jangan jalankan script ini sebagai root!${NC}"
   echo "Gunakan: sudo -u username ./setup-ip.sh"
   exit 1
fi

# Get VPS IP address
echo -e "${YELLOW}🔍 Mendeteksi IP address VPS...${NC}"
VPS_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
echo -e "${GREEN}📍 IP VPS: $VPS_IP${NC}"

# Create SSL directory
echo -e "${YELLOW}📁 Membuat direktori SSL...${NC}"
mkdir -p ssl

# Generate self-signed SSL certificate
echo -e "${YELLOW}🔐 Membuat SSL certificate self-signed...${NC}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$VPS_IP"

# Create necessary directories
echo -e "${YELLOW}📁 Membuat direktori yang diperlukan...${NC}"
mkdir -p .data/CTFd/logs
mkdir -p .data/CTFd/uploads
mkdir -p .data/mysql
mkdir -p .data/redis

# Setup firewall
echo -e "${YELLOW}🔥 Mengkonfigurasi firewall...${NC}"
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Start CTFd
echo -e "${YELLOW}🚀 Menjalankan CTFd...${NC}"
docker-compose -f docker-compose.ip.yml up -d

# Wait for services
echo -e "${YELLOW}⏳ Menunggu services siap...${NC}"
sleep 30

# Check status
echo -e "${YELLOW}🔍 Memeriksa status services...${NC}"
docker-compose -f docker-compose.ip.yml ps

# Create management script
cat > manage-ctfd-ip.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Starting CTFd..."
        docker-compose -f docker-compose.ip.yml up -d
        ;;
    stop)
        echo "🛑 Stopping CTFd..."
        docker-compose -f docker-compose.ip.yml down
        ;;
    restart)
        echo "🔄 Restarting CTFd..."
        docker-compose -f docker-compose.ip.yml restart
        ;;
    logs)
        echo "📋 Showing CTFd logs..."
        docker-compose -f docker-compose.ip.yml logs -f
        ;;
    status)
        echo "📊 CTFd status:"
        docker-compose -f docker-compose.ip.yml ps
        ;;
    update)
        echo "🔄 Updating CTFd..."
        git pull
        docker-compose -f docker-compose.ip.yml build
        docker-compose -f docker-compose.ip.yml up -d
        ;;
    backup)
        echo "💾 Creating backup..."
        DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="/backup/ctfd_$DATE"
        mkdir -p $BACKUP_DIR
        docker-compose -f docker-compose.ip.yml exec -T db mysqldump -u ctfd -pctfd ctfd > $BACKUP_DIR/database.sql
        cp -r .data/CTFd/uploads $BACKUP_DIR/
        echo "✅ Backup created: $BACKUP_DIR"
        ;;
    ssl)
        echo "🔐 Regenerating SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$(curl -s ifconfig.me)"
        docker-compose -f docker-compose.ip.yml restart nginx
        echo "✅ SSL certificate regenerated!"
        ;;
    *)
        echo "CTFd IP Management Script"
        echo "Usage: $0 {start|stop|restart|logs|status|update|backup|ssl}"
        echo ""
        echo "Commands:"
        echo "  start   - Start CTFd services"
        echo "  stop    - Stop CTFd services"
        echo "  restart - Restart CTFd services"
        echo "  logs    - Show CTFd logs"
        echo "  status  - Show service status"
        echo "  update  - Update CTFd to latest version"
        echo "  backup  - Create backup of database and uploads"
        echo "  ssl     - Regenerate SSL certificate"
        ;;
esac
EOF

chmod +x manage-ctfd-ip.sh

# Create simple access script
cat > access-ctfd.sh << EOF
#!/bin/bash

echo "🌐 CTFd Access Information"
echo "========================="
echo ""
echo "📍 VPS IP: $VPS_IP"
echo ""
echo "🔗 Akses CTFd:"
echo "   HTTP:  http://$VPS_IP (redirect ke HTTPS)"
echo "   HTTPS: https://$VPS_IP"
echo ""
echo "⚠️  Catatan:"
echo "   - Browser akan menampilkan warning SSL karena self-signed certificate"
echo "   - Klik 'Advanced' dan 'Proceed to site' untuk melanjutkan"
echo "   - Atau tambahkan exception di browser"
echo ""
echo "🛠️  Management:"
echo "   ./manage-ctfd-ip.sh status  - Cek status"
echo "   ./manage-ctfd-ip.sh logs    - Lihat logs"
echo "   ./manage-ctfd-ip.sh restart - Restart services"
echo ""
EOF

chmod +x access-ctfd.sh

# Final status
echo ""
echo -e "${GREEN}🎉 CTFd berhasil di-deploy!${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}🌐 Akses CTFd:${NC}"
echo "   HTTP:  http://$VPS_IP (redirect ke HTTPS)"
echo "   HTTPS: https://$VPS_IP"
echo ""
echo -e "${BLUE}🛠️  Manajemen:${NC}"
echo "   Status:  ./manage-ctfd-ip.sh status"
echo "   Logs:    ./manage-ctfd-ip.sh logs"
echo "   Restart: ./manage-ctfd-ip.sh restart"
echo "   Stop:    ./manage-ctfd-ip.sh stop"
echo "   Start:   ./manage-ctfd-ip.sh start"
echo ""
echo -e "${YELLOW}⚠️  Catatan Penting:${NC}"
echo "1. Browser akan menampilkan warning SSL (normal untuk self-signed)"
echo "2. Klik 'Advanced' → 'Proceed to site' untuk melanjutkan"
echo "3. SSL certificate berlaku 365 hari"
echo "4. Jalankan './manage-ctfd-ip.sh ssl' untuk regenerate SSL"
echo ""
echo -e "${GREEN}✅ Setup selesai! CTFd siap digunakan di https://$VPS_IP${NC}"
echo ""
echo "Jalankan './access-ctfd.sh' untuk melihat informasi akses"
