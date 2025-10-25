# Electronic Signature System - Production Deployment Guide

Complete guide for deploying the Electronic Signature System in production.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture

The production stack consists of:

- **DocuSeal** - Rails application for document signing
- **PostgreSQL 15** - Main database
- **Redis 7** - Background job processing
- **DSS Service (Java 21)** - PAdES-LTA digital signatures
- **Caddy 2** - Reverse proxy with automatic HTTPS

```
Internet
   ↓
Caddy (Port 80/443)
   ↓
DocuSeal (Port 3000) ←→ PostgreSQL (Port 5432)
   ↓                     ↓
   ↓                   Redis (Port 6379)
   ↓
DSS Service (Port 4000)
```

---

## ✅ Prerequisites

### Server Requirements

**Minimum:**
- 2 CPU cores
- 4 GB RAM
- 20 GB disk space
- Ubuntu 20.04+ / Debian 11+ / CentOS 8+

**Recommended:**
- 4 CPU cores
- 8 GB RAM
- 50 GB SSD
- Ubuntu 22.04 LTS

### Software Requirements

1. **Docker Engine** (20.10+)
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

2. **Docker Compose** (v2.0+)
   ```bash
   # Already included with Docker Desktop
   # For servers, install Docker Compose plugin:
   sudo apt-get install docker-compose-plugin
   ```

3. **Domain Name**
   - Point your domain A record to your server IP
   - Example: `sign.example.com → 203.0.113.1`

4. **PKCS12 Certificate**
   - `.p12` file with private key for digital signatures
   - Password for the certificate

---

## 🚀 Initial Setup

### Step 1: Clone Repository

```bash
cd /opt
git clone https://github.com/yourorg/electronic_signature.git
cd electronic_signature
```

### Step 2: Configure Environment

```bash
# Copy environment template
cp .env.prod.example .env.prod

# Edit configuration
nano .env.prod
```

**Required configurations:**

```bash
# Application
APP_HOST=sign.example.com
ACME_EMAIL=admin@example.com

# Generate secrets (run these commands):
SECRET_KEY_BASE=$(openssl rand -hex 64)
ENCRYPTION_KEY=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)

# Certificate
P12_CERT_PATH=/opt/electronic_signature/certificates/certificate.p12
P12_PASSWORD=your-certificate-password
```

### Step 3: Place Certificate

```bash
# Create certificate directory
mkdir -p /opt/electronic_signature/certificates

# Copy your P12 certificate
cp /path/to/your/certificate.p12 /opt/electronic_signature/certificates/

# Secure permissions
chmod 600 /opt/electronic_signature/certificates/certificate.p12
```

### Step 4: Configure Email (Optional but Recommended)

Edit `.env.prod` and add SMTP settings:

```bash
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_DOMAIN=gmail.com
SMTP_FROM=noreply@example.com
```

For Gmail, create an App Password: https://myaccount.google.com/apppasswords

---

## 🚢 Deployment

### First-Time Deployment

```bash
# Make deploy script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh --build
```

This will:
1. ✅ Validate configuration
2. ✅ Build Docker images
3. ✅ Start all services
4. ✅ Run database migrations
5. ✅ Configure Caddy with automatic HTTPS

### Accessing the Application

After deployment completes (2-5 minutes):

- **Main App**: `https://sign.example.com`
- **Health Check**: `https://sign.example.com/health`

Caddy will automatically obtain SSL certificates from Let's Encrypt.

---

## ⚙️ Configuration

### Caddy Configuration

The Caddyfile is located at `/Users/paco/desa/projects/electronic_signature/Caddyfile`

**Features:**
- ✅ Automatic HTTPS with Let's Encrypt
- ✅ HTTP/2 and HTTP/3 support
- ✅ Automatic HTTP → HTTPS redirect
- ✅ Security headers (HSTS, XSS protection, etc.)
- ✅ Gzip compression
- ✅ 100MB max upload size (for PDFs)

**Custom Domain:**
```bash
# Update .env.prod
APP_HOST=yourdomain.com
ACME_EMAIL=admin@yourdomain.com

# Redeploy
./deploy.sh
```

### Storage Configuration

**Local Storage (Default):**
Files stored in Docker volume `docuseal_data`

**Cloud Storage (AWS S3):**

```bash
# Edit .env.prod
ACTIVE_STORAGE_SERVICE=amazon
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key

# Redeploy
./deploy.sh
```

**Google Cloud Storage:**

```bash
ACTIVE_STORAGE_SERVICE=google
GCS_BUCKET=your-bucket-name
GCS_PROJECT=your-project-id
GCS_KEYFILE=/path/to/keyfile.json
```

### Performance Tuning

Edit `.env.prod`:

```bash
# Web server processes (1-2 per CPU core)
WEB_CONCURRENCY=4

# Threads per process (5-10)
RAILS_MAX_THREADS=10
```

---

## 🔧 Maintenance

### View Logs

```bash
# All services
docker compose -f docker-compose.prod.yml logs -f

# Specific service
docker compose -f docker-compose.prod.yml logs -f docuseal
docker compose -f docker-compose.prod.yml logs -f dss-service
docker compose -f docker-compose.prod.yml logs -f caddy
```

### Restart Services

```bash
# All services
docker compose -f docker-compose.prod.yml restart

# Specific service
docker compose -f docker-compose.prod.yml restart docuseal
```

### Update Application

```bash
# Pull latest code
git pull

# Rebuild and deploy
./deploy.sh --build
```

### Backup

```bash
# Make backup script executable
chmod +x backup.sh

# Run backup
./backup.sh

# Backups saved to: ./backups/backup_YYYYMMDD_HHMMSS/
```

**Automatic Backups with Cron:**

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /opt/electronic_signature && ./backup.sh > /var/log/backup.log 2>&1
```

### Restore from Backup

```bash
# Stop services
docker compose -f docker-compose.prod.yml down

# Restore database
gunzip < backups/backup_YYYYMMDD_HHMMSS/database.sql.gz | \
  docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d docuseal_production

# Restore files
docker run --rm \
  -v electronic_signature_docuseal_data:/data \
  -v $(pwd)/backups/backup_YYYYMMDD_HHMMSS:/backup \
  alpine \
  tar xzf /backup/docuseal_files.tar.gz -C /data

# Start services
docker compose -f docker-compose.prod.yml up -d
```

### Database Console

```bash
docker compose -f docker-compose.prod.yml exec postgres \
  psql -U postgres -d docuseal_production
```

### Rails Console

```bash
docker compose -f docker-compose.prod.yml exec docuseal \
  bundle exec rails console
```

### Monitor Resources

```bash
# Container stats
docker stats

# Disk usage
docker system df

# Clean up unused data
docker system prune -a
```

---

## 🔍 Troubleshooting

### SSL Certificate Issues

**Problem:** Certificate not obtained

```bash
# Check Caddy logs
docker compose -f docker-compose.prod.yml logs caddy

# Common issues:
# - Port 80/443 not accessible
# - Domain not pointing to server
# - Firewall blocking ports
```

**Solution:**
```bash
# Check ports
sudo netstat -tlnp | grep -E '80|443'

# Check DNS
dig sign.example.com

# Allow ports in firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Database Connection Error

**Problem:** `could not connect to server`

```bash
# Check PostgreSQL status
docker compose -f docker-compose.prod.yml ps postgres

# Check logs
docker compose -f docker-compose.prod.yml logs postgres
```

**Solution:**
```bash
# Restart PostgreSQL
docker compose -f docker-compose.prod.yml restart postgres
```

### Out of Memory

**Problem:** Container killed by OOM

```bash
# Check memory usage
docker stats

# Increase swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### DSS Service Not Working

**Problem:** Signature failing

```bash
# Check DSS service logs
docker compose -f docker-compose.prod.yml logs dss-service

# Check certificate
docker compose -f docker-compose.prod.yml exec dss-service \
  ls -la /app/certificate.p12
```

### Application Not Loading

```bash
# Check all services
docker compose -f docker-compose.prod.yml ps

# Check DocuSeal logs
docker compose -f docker-compose.prod.yml logs docuseal

# Check database migrations
docker compose -f docker-compose.prod.yml exec docuseal \
  bundle exec rails db:migrate:status
```

---

## 🔐 Security Best Practices

1. **Change Default Passwords**
   - Generate strong passwords for all services
   - Never use example passwords in production

2. **Keep System Updated**
   ```bash
   sudo apt update && sudo apt upgrade -y
   docker compose -f docker-compose.prod.yml pull
   ```

3. **Enable Firewall**
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp   # SSH
   sudo ufw allow 80/tcp   # HTTP
   sudo ufw allow 443/tcp  # HTTPS
   ```

4. **Limit SSH Access**
   ```bash
   # Edit /etc/ssh/sshd_config
   PermitRootLogin no
   PasswordAuthentication no
   ```

5. **Regular Backups**
   - Automated daily backups
   - Test restore procedures
   - Store backups off-site

6. **Monitor Logs**
   - Set up log rotation
   - Monitor for suspicious activity
   - Use centralized logging (optional)

---

## 📞 Support

For issues or questions:
- Check logs: `docker compose -f docker-compose.prod.yml logs`
- Review this guide
- Check DocuSeal documentation: https://docs.docuseal.co
- GitHub Issues: https://github.com/docusealco/docuseal/issues

---

## 📄 License

Same as DocuSeal - AGPL-3.0
