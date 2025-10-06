#!/bin/bash

# CTFd IP-Only Setup Script untuk ROOT
# Script khusus untuk VPS yang sudah dalam kondisi root

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
echo "║                    (ROOT VERSION)                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Script ini harus dijalankan sebagai root!${NC}"
   echo "Gunakan: sudo ./setup-ip-root.sh"
   exit 1
fi

echo -e "${GREEN}✅ Script dijalankan sebagai root${NC}"

# Update system
echo -e "${YELLOW}🔄 Mengupdate sistem...${NC}"
apt-get update -y

# Install required packages
echo -e "${YELLOW}📦 Menginstall package yang diperlukan...${NC}"
apt-get install -y curl wget openssl ufw

# Install Docker if not exists
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}✅ Docker berhasil diinstall${NC}"
else
    echo -e "${GREEN}✅ Docker sudah terinstall${NC}"
fi

# Install Docker Compose if not exists
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose berhasil diinstall${NC}"
else
    echo -e "${GREEN}✅ Docker Compose sudah terinstall${NC}"
fi

# Get VPS IP address
echo -e "${YELLOW}🔍 Mendeteksi IP address VPS...${NC}"
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
echo -e "${GREEN}📍 IP VPS: $VPS_IP${NC}"

# Validate IP address
if [[ ! $VPS_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}❌ Tidak bisa mendeteksi IP VPS. Masukkan IP secara manual:${NC}"
    read -p "IP VPS: " VPS_IP
fi

# Create SSL directory
echo -e "${YELLOW}📁 Membuat direktori SSL...${NC}"
mkdir -p ssl

# Generate self-signed SSL certificate
echo -e "${YELLOW}🔐 Membuat SSL certificate self-signed...${NC}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$VPS_IP" 2>/dev/null
echo -e "${GREEN}✅ SSL certificate berhasil dibuat${NC}"

# Create necessary directories
echo -e "${YELLOW}📁 Membuat direktori yang diperlukan...${NC}"
mkdir -p .data/CTFd/logs
mkdir -p .data/CTFd/uploads
mkdir -p .data/mysql
mkdir -p .data/redis

# Setup firewall
echo -e "${YELLOW}🔥 Mengkonfigurasi firewall...${NC}"
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable
echo -e "${GREEN}✅ Firewall berhasil dikonfigurasi${NC}"

# Start CTFd
echo -e "${YELLOW}🚀 Menjalankan CTFd...${NC}"
if docker-compose -f docker-compose.ip.yml up -d; then
    echo -e "${GREEN}✅ CTFd berhasil dijalankan${NC}"
else
    echo -e "${RED}❌ Gagal menjalankan CTFd. Cek logs:${NC}"
    docker-compose -f docker-compose.ip.yml logs
    exit 1
fi

# Wait for services
echo -e "${YELLOW}⏳ Menunggu services siap...${NC}"
sleep 30

# Check status
echo -e "${YELLOW}🔍 Memeriksa status services...${NC}"
docker-compose -f docker-compose.ip.yml ps

# Create management script
cat > manage-ctfd-root.sh << 'EOF'
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
        VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null)
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$VPS_IP"
        docker-compose -f docker-compose.ip.yml restart nginx
        echo "✅ SSL certificate regenerated!"
        ;;
    *)
        echo "CTFd Root Management Script"
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

chmod +x manage-ctfd-root.sh

# Create simple access script
cat > access-ctfd-root.sh << EOF
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
echo "   ./manage-ctfd-root.sh status  - Cek status"
echo "   ./manage-ctfd-root.sh logs    - Lihat logs"
echo "   ./manage-ctfd-root.sh restart - Restart services"
echo ""
EOF

chmod +x access-ctfd-root.sh

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
echo "   Status:  ./manage-ctfd-root.sh status"
echo "   Logs:    ./manage-ctfd-root.sh logs"
echo "   Restart: ./manage-ctfd-root.sh restart"
echo "   Stop:    ./manage-ctfd-root.sh stop"
echo "   Start:   ./manage-ctfd-root.sh start"
echo ""
echo -e "${YELLOW}⚠️  Catatan Penting:${NC}"
echo "1. Browser akan menampilkan warning SSL (normal untuk self-signed)"
echo "2. Klik 'Advanced' → 'Proceed to site' untuk melanjutkan"
echo "3. SSL certificate berlaku 365 hari"
echo "4. Jalankan './manage-ctfd-root.sh ssl' untuk regenerate SSL"
echo ""
echo -e "${GREEN}✅ Setup selesai! CTFd siap digunakan di https://$VPS_IP${NC}"
echo ""
echo "Jalankan './access-ctfd-root.sh' untuk melihat informasi akses"
