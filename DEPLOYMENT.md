# CTFd VPS Deployment dengan HTTPS

Panduan lengkap untuk menjalankan CTFd di VPS dengan IP public dan HTTPS.

## Prerequisites

1. **VPS dengan Ubuntu/Debian** (direkomendasikan Ubuntu 20.04+)
2. **Domain name** yang mengarah ke IP VPS Anda
3. **Docker dan Docker Compose** terinstall
4. **Port 80 dan 443** terbuka di firewall

## Langkah-langkah Deployment

### 1. Persiapan VPS

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git
sudo apt install git -y

# Logout dan login kembali untuk apply group changes
```

### 2. Clone dan Setup CTFd

```bash
# Clone repository (jika belum)
git clone https://github.com/CTFd/CTFd.git
cd CTFd

# Atau jika sudah ada, pastikan di direktori CTFd
```

### 3. Konfigurasi Domain

Edit file `conf/nginx/https.conf` dan ganti `your-domain.com` dengan domain Anda:

```bash
# Ganti domain di nginx config
sed -i 's/your-domain.com/ctfd.example.com/g' conf/nginx/https.conf

# Ganti domain di docker-compose
sed -i 's/your-domain.com/ctfd.example.com/g' docker-compose.https.yml
```

### 4. Setup SSL Certificate

```bash
# Jalankan script setup SSL
chmod +x setup-ssl.sh
./setup-ssl.sh
```

Script ini akan:
- Meminta domain dan email Anda
- Membuat direktori yang diperlukan
- Generate SSL certificate menggunakan Let's Encrypt
- Setup automatic renewal
- Menjalankan CTFd dengan HTTPS

### 5. Konfigurasi Firewall

```bash
# Buka port yang diperlukan
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw enable
```

### 6. Verifikasi Deployment

Setelah setup selesai, akses:
- **HTTP**: `http://your-domain.com` (akan redirect ke HTTPS)
- **HTTPS**: `https://your-domain.com`

## Manajemen CTFd

### Perintah Dasar

```bash
# Start CTFd
docker-compose -f docker-compose.https.yml up -d

# Stop CTFd
docker-compose -f docker-compose.https.yml down

# Restart CTFd
docker-compose -f docker-compose.https.yml restart

# Lihat logs
docker-compose -f docker-compose.https.yml logs -f

# Update CTFd
git pull
docker-compose -f docker-compose.https.yml build
docker-compose -f docker-compose.https.yml up -d
```

### Renewal SSL Certificate

```bash
# Manual renewal
./renew-ssl.sh

# Check renewal logs
tail -f ssl-renewal.log
```

## Konfigurasi Tambahan

### 1. Email Configuration

Edit file `env.example` dan copy ke `.env`:

```bash
cp env.example .env
nano .env
```

Update konfigurasi email:
```
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USEAUTH=true
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_TLS=true
MAILFROM_ADDR=noreply@your-domain.com
```

### 2. Database Configuration

Untuk production, pertimbangkan menggunakan database eksternal:

```bash
# Update DATABASE_URL di .env
DATABASE_URL=mysql+pymysql://username:password@external-db-host:3306/ctfd
```

### 3. Backup Configuration

Buat script backup:

```bash
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/ctfd_$DATE"

mkdir -p $BACKUP_DIR

# Backup database
docker-compose -f docker-compose.https.yml exec -T db mysqldump -u ctfd -pctfd ctfd > $BACKUP_DIR/database.sql

# Backup uploads
cp -r .data/CTFd/uploads $BACKUP_DIR/

# Backup logs
cp -r .data/CTFd/logs $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup.sh
```

## Troubleshooting

### 1. SSL Certificate Issues

```bash
# Check certificate status
docker-compose -f docker-compose.https.yml exec nginx nginx -t

# Check certificate files
ls -la /etc/letsencrypt/live/your-domain.com/

# Renew certificate manually
docker-compose -f docker-compose.https.yml run --rm certbot renew
```

### 2. Nginx Issues

```bash
# Check nginx config
docker-compose -f docker-compose.https.yml exec nginx nginx -t

# Reload nginx
docker-compose -f docker-compose.https.yml exec nginx nginx -s reload

# Check nginx logs
docker-compose -f docker-compose.https.yml logs nginx
```

### 3. CTFd Application Issues

```bash
# Check CTFd logs
docker-compose -f docker-compose.https.yml logs ctfd

# Check database connection
docker-compose -f docker-compose.https.yml exec db mysql -u ctfd -pctfd -e "SHOW DATABASES;"

# Check Redis connection
docker-compose -f docker-compose.https.yml exec cache redis-cli ping
```

### 4. Port Issues

```bash
# Check port usage
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Kill process using port
sudo fuser -k 80/tcp
sudo fuser -k 443/tcp
```

## Security Best Practices

1. **Update secara berkala**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   docker-compose -f docker-compose.https.yml pull
   ```

2. **Backup rutin**:
   ```bash
   # Setup cron job untuk backup harian
   (crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup.sh") | crontab -
   ```

3. **Monitor logs**:
   ```bash
   # Setup log rotation
   sudo nano /etc/logrotate.d/ctfd
   ```

4. **Firewall configuration**:
   ```bash
   # Hanya buka port yang diperlukan
   sudo ufw status
   ```

## Performance Optimization

1. **Increase workers** (untuk VPS dengan RAM lebih):
   ```bash
   # Edit docker-compose.https.yml
   - WORKERS=2  # atau lebih sesuai RAM
   ```

2. **Database optimization**:
   ```bash
   # Edit MariaDB configuration
   # Tambahkan di command MariaDB:
   --innodb_buffer_pool_size=256M
   ```

3. **Nginx caching**:
   ```bash
   # Tambahkan di nginx config:
   location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
       expires 1y;
       add_header Cache-Control "public, immutable";
   }
   ```

## Monitoring

Setup monitoring dengan:

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs -y

# Monitor resources
htop
iotop
nethogs
```

## Support

Jika mengalami masalah:

1. Check logs: `docker-compose -f docker-compose.https.yml logs`
2. Check status: `docker-compose -f docker-compose.https.yml ps`
3. Restart services: `docker-compose -f docker-compose.https.yml restart`
4. Check disk space: `df -h`
5. Check memory: `free -h`

---

**Catatan**: Pastikan domain Anda sudah mengarah ke IP VPS sebelum menjalankan setup SSL. Let's Encrypt memerlukan verifikasi domain untuk generate certificate.
