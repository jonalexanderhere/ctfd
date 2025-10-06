#!/bin/bash

# CTFd Direct Installation Script (Tanpa Docker)
# Install CTFd langsung di VPS tanpa Docker

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                CTFd Direct Installation                      ║"
echo "║              Tanpa Docker - Langsung di VPS                 ║"
echo "║                    (ROOT VERSION)                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Script ini harus dijalankan sebagai root!${NC}"
   echo "Gunakan: sudo ./setup-ctfd-direct.sh"
   exit 1
fi

echo -e "${GREEN}✅ Script dijalankan sebagai root${NC}"

# Update system
echo -e "${YELLOW}🔄 Mengupdate sistem...${NC}"
apt-get update -y

# Install required packages
echo -e "${YELLOW}📦 Menginstall package yang diperlukan...${NC}"
apt-get install -y python3 python3-pip python3-venv python3-dev \
    nginx mysql-server redis-server git curl wget openssl ufw \
    build-essential libffi-dev libssl-dev

# Start and enable services
echo -e "${YELLOW}🚀 Menjalankan services...${NC}"
systemctl start mysql
systemctl enable mysql
systemctl start redis-server
systemctl enable redis-server
systemctl start nginx
systemctl enable nginx

# Get VPS IP address
echo -e "${YELLOW}🔍 Mendeteksi IP address VPS...${NC}"
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
echo -e "${GREEN}📍 IP VPS: $VPS_IP${NC}"

# Validate IP address
if [[ ! $VPS_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}❌ Tidak bisa mendeteksi IP VPS. Masukkan IP secara manual:${NC}"
    read -p "IP VPS: " VPS_IP
fi

# Create CTFd user
echo -e "${YELLOW}👤 Membuat user CTFd...${NC}"
if ! id "ctfd" &>/dev/null; then
    useradd -m -s /bin/bash ctfd
    echo -e "${GREEN}✅ User 'ctfd' berhasil dibuat${NC}"
else
    echo -e "${GREEN}✅ User 'ctfd' sudah ada${NC}"
fi

# Create CTFd directory
echo -e "${YELLOW}📁 Membuat direktori CTFd...${NC}"
mkdir -p /opt/ctfd
cd /opt/ctfd

# Clone CTFd if not exists
if [ ! -d "CTFd" ]; then
    echo -e "${YELLOW}📥 Mengclone CTFd...${NC}"
    git clone https://github.com/CTFd/CTFd.git
fi

cd CTFd

# Create virtual environment
echo -e "${YELLOW}🐍 Membuat virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo -e "${YELLOW}📦 Menginstall Python dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

# Install additional dependencies
pip install gunicorn

# Setup MySQL database
echo -e "${YELLOW}🗄️  Setup database MySQL...${NC}"
mysql -e "CREATE DATABASE IF NOT EXISTS ctfd;"
mysql -e "CREATE USER IF NOT EXISTS 'ctfd'@'localhost' IDENTIFIED BY 'ctfd';"
mysql -e "GRANT ALL PRIVILEGES ON ctfd.* TO 'ctfd'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create CTFd configuration
echo -e "${YELLOW}⚙️  Membuat konfigurasi CTFd...${NC}"
cat > /opt/ctfd/CTFd/config.ini << EOF
[server]
SECRET_KEY = $(openssl rand -hex 32)
DATABASE_URL = mysql+pymysql://ctfd:ctfd@localhost/ctfd
REDIS_URL = redis://localhost:6379

[security]
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = Lax
PERMANENT_SESSION_LIFETIME = 604800

[email]
MAILFROM_ADDR = noreply@$VPS_IP

[logs]
LOG_FOLDER = /opt/ctfd/logs

[uploads]
UPLOAD_FOLDER = /opt/ctfd/uploads

[optional]
REVERSE_PROXY = True
TEMPLATES_AUTO_RELOAD = False
THEME_FALLBACK = True
SQLALCHEMY_TRACK_MODIFICATIONS = False
SWAGGER_UI = False
UPDATE_CHECK = True
SERVER_SENT_EVENTS = True
HTML_SANITIZATION = False
SAFE_MODE = False
EOF

# Create necessary directories
echo -e "${YELLOW}📁 Membuat direktori yang diperlukan...${NC}"
mkdir -p /opt/ctfd/logs
mkdir -p /opt/ctfd/uploads
mkdir -p /opt/ctfd/ssl

# Generate SSL certificate
echo -e "${YELLOW}🔐 Membuat SSL certificate...${NC}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/ctfd/ssl/key.pem \
    -out /opt/ctfd/ssl/cert.pem \
    -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$VPS_IP" 2>/dev/null

# Set permissions
chown -R ctfd:ctfd /opt/ctfd
chmod +x /opt/ctfd/CTFd/docker-entrypoint.sh

# Create systemd service
echo -e "${YELLOW}🔧 Membuat systemd service...${NC}"
cat > /etc/systemd/system/ctfd.service << EOF
[Unit]
Description=CTFd
After=network.target mysql.service redis.service

[Service]
Type=exec
User=ctfd
Group=ctfd
WorkingDirectory=/opt/ctfd/CTFd
Environment=PATH=/opt/ctfd/CTFd/venv/bin
ExecStart=/opt/ctfd/CTFd/venv/bin/gunicorn --bind 127.0.0.1:8000 --workers 4 --worker-class gevent --worker-connections 1000 --max-requests 1000 --max-requests-jitter 100 --timeout 30 --keep-alive 2 --preload 'CTFd:create_app()'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration
echo -e "${YELLOW}🌐 Membuat konfigurasi Nginx...${NC}"
cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $VPS_IP;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $VPS_IP;

    ssl_certificate /opt/ctfd/ssl/cert.pem;
    ssl_certificate_key /opt/ctfd/ssl/key.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 4G;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /events {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/ctfd /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Setup firewall
echo -e "${YELLOW}🔥 Mengkonfigurasi firewall...${NC}"
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

# Initialize CTFd database
echo -e "${YELLOW}🗄️  Menginisialisasi database CTFd...${NC}"
cd /opt/ctfd/CTFd
sudo -u ctfd bash -c "source venv/bin/activate && python manage.py db upgrade"

# Start services
echo -e "${YELLOW}🚀 Menjalankan services...${NC}"
systemctl daemon-reload
systemctl start ctfd
systemctl enable ctfd
systemctl reload nginx

# Wait for services
echo -e "${YELLOW}⏳ Menunggu services siap...${NC}"
sleep 10

# Check status
echo -e "${YELLOW}🔍 Memeriksa status services...${NC}"
systemctl status ctfd --no-pager
systemctl status nginx --no-pager

# Create management script
cat > /usr/local/bin/manage-ctfd << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Starting CTFd..."
        systemctl start ctfd
        systemctl start nginx
        ;;
    stop)
        echo "🛑 Stopping CTFd..."
        systemctl stop ctfd
        systemctl stop nginx
        ;;
    restart)
        echo "🔄 Restarting CTFd..."
        systemctl restart ctfd
        systemctl restart nginx
        ;;
    status)
        echo "📊 CTFd status:"
        systemctl status ctfd --no-pager
        systemctl status nginx --no-pager
        ;;
    logs)
        echo "📋 Showing CTFd logs..."
        journalctl -u ctfd -f
        ;;
    update)
        echo "🔄 Updating CTFd..."
        cd /opt/ctfd/CTFd
        git pull
        source venv/bin/activate
        pip install -r requirements.txt
        python manage.py db upgrade
        systemctl restart ctfd
        ;;
    backup)
        echo "💾 Creating backup..."
        DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="/backup/ctfd_$DATE"
        mkdir -p $BACKUP_DIR
        mysqldump -u ctfd -pctfd ctfd > $BACKUP_DIR/database.sql
        cp -r /opt/ctfd/uploads $BACKUP_DIR/
        echo "✅ Backup created: $BACKUP_DIR"
        ;;
    ssl)
        echo "🔐 Regenerating SSL certificate..."
        VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null)
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /opt/ctfd/ssl/key.pem \
            -out /opt/ctfd/ssl/cert.pem \
            -subj "/C=ID/ST=Indonesia/L=Jakarta/O=CTFd/OU=IT/CN=$VPS_IP"
        systemctl restart nginx
        echo "✅ SSL certificate regenerated!"
        ;;
    *)
        echo "CTFd Management Script"
        echo "Usage: $0 {start|stop|restart|status|logs|update|backup|ssl}"
        echo ""
        echo "Commands:"
        echo "  start   - Start CTFd services"
        echo "  stop    - Stop CTFd services"
        echo "  restart - Restart CTFd services"
        echo "  status  - Show service status"
        echo "  logs    - Show CTFd logs"
        echo "  update  - Update CTFd to latest version"
        echo "  backup  - Create backup of database and uploads"
        echo "  ssl     - Regenerate SSL certificate"
        ;;
esac
EOF

chmod +x /usr/local/bin/manage-ctfd

# Create access info script
cat > /usr/local/bin/ctfd-info << EOF
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
echo "   manage-ctfd status  - Cek status"
echo "   manage-ctfd logs    - Lihat logs"
echo "   manage-ctfd restart - Restart services"
echo ""
echo "📁 File Locations:"
echo "   CTFd: /opt/ctfd/CTFd"
echo "   Logs: /opt/ctfd/logs"
echo "   Uploads: /opt/ctfd/uploads"
echo "   SSL: /opt/ctfd/ssl"
echo ""
EOF

chmod +x /usr/local/bin/ctfd-info

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
echo "   Status:  manage-ctfd status"
echo "   Logs:    manage-ctfd logs"
echo "   Restart: manage-ctfd restart"
echo "   Stop:    manage-ctfd stop"
echo "   Start:   manage-ctfd start"
echo ""
echo -e "${YELLOW}⚠️  Catatan Penting:${NC}"
echo "1. Browser akan menampilkan warning SSL (normal untuk self-signed)"
echo "2. Klik 'Advanced' → 'Proceed to site' untuk melanjutkan"
echo "3. SSL certificate berlaku 365 hari"
echo "4. Jalankan 'manage-ctfd ssl' untuk regenerate SSL"
echo ""
echo -e "${GREEN}✅ Setup selesai! CTFd siap digunakan di https://$VPS_IP${NC}"
echo ""
echo "Jalankan 'ctfd-info' untuk melihat informasi lengkap"
