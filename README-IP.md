# CTFd IP-Only Setup (Tanpa Domain)

Setup CTFd yang super mudah menggunakan IP address VPS langsung dengan HTTPS self-signed.

## 🚀 Quick Start (1 Command)

```bash
chmod +x setup-ip.sh
./setup-ip.sh
```

**Selesai!** CTFd akan berjalan di `https://YOUR_VPS_IP`

## 📋 Yang Dibutuhkan

1. **VPS Ubuntu/Debian** dengan IP public
2. **Docker & Docker Compose** (script akan install otomatis)
3. **Port 80 & 443** terbuka

## 🔧 File yang Dibuat

- `docker-compose.ip.yml` - Konfigurasi Docker untuk IP-only
- `conf/nginx/ip-https.conf` - Nginx config dengan SSL self-signed
- `setup-ip.sh` - Script setup otomatis
- `manage-ctfd-ip.sh` - Script manajemen CTFd
- `access-ctfd.sh` - Script info akses

## 🛠️ Manajemen CTFd

```bash
# Cek status
./manage-ctfd-ip.sh status

# Lihat logs
./manage-ctfd-ip.sh logs

# Restart
./manage-ctfd-ip.sh restart

# Stop
./manage-ctfd-ip.sh stop

# Start
./manage-ctfd-ip.sh start

# Update
./manage-ctfd-ip.sh update

# Backup
./manage-ctfd-ip.sh backup

# Regenerate SSL
./manage-ctfd-ip.sh ssl
```

## 🌐 Akses CTFd

Setelah setup selesai:

- **HTTP**: `http://YOUR_VPS_IP` (redirect ke HTTPS)
- **HTTPS**: `https://YOUR_VPS_IP`

## ⚠️ SSL Warning

Browser akan menampilkan warning karena menggunakan self-signed certificate:

1. Klik **"Advanced"**
2. Klik **"Proceed to site"** atau **"Continue to site"**
3. CTFd akan berjalan normal

## 🔐 Keamanan

- SSL self-signed (aman untuk internal/testing)
- Rate limiting untuk login dan API
- Security headers
- Firewall otomatis (port 22, 80, 443)

## 📊 Monitoring

```bash
# Cek status services
docker-compose -f docker-compose.ip.yml ps

# Cek logs real-time
docker-compose -f docker-compose.ip.yml logs -f

# Cek resource usage
docker stats
```

## 🔄 Update CTFd

```bash
# Update ke versi terbaru
./manage-ctfd-ip.sh update
```

## 💾 Backup

```bash
# Backup database dan uploads
./manage-ctfd-ip.sh backup
```

## 🆘 Troubleshooting

### CTFd tidak bisa diakses
```bash
# Cek status
./manage-ctfd-ip.sh status

# Cek logs
./manage-ctfd-ip.sh logs

# Restart
./manage-ctfd-ip.sh restart
```

### SSL Error
```bash
# Regenerate SSL certificate
./manage-ctfd-ip.sh ssl
```

### Port sudah digunakan
```bash
# Cek port yang digunakan
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Kill process
sudo fuser -k 80/tcp
sudo fuser -k 443/tcp
```

### Database Error
```bash
# Restart database
docker-compose -f docker-compose.ip.yml restart db

# Cek database logs
docker-compose -f docker-compose.ip.yml logs db
```

## 📝 Catatan

1. **SSL Certificate** berlaku 365 hari
2. **Self-signed certificate** aman untuk internal use
3. **Tidak perlu domain** - langsung pakai IP
4. **Setup sekali** - jalan terus
5. **Backup rutin** untuk data penting

## 🎯 Keuntungan Setup Ini

✅ **Tidak ribet** - tidak perlu domain  
✅ **Cepat setup** - 1 command selesai  
✅ **HTTPS ready** - SSL otomatis  
✅ **Easy management** - script lengkap  
✅ **Production ready** - bisa untuk CTF nyata  

---

**Ready to CTF!** 🏆
