#!/bin/bash
# Backup Script for Electronic Signature System
#
# Creates backups of:
# - PostgreSQL database
# - DocuSeal uploaded files
# - Redis data
#
# Usage:
#   cd docuseal/
#   ./backup.sh                    # Create backup with timestamp
#   ./backup.sh /path/to/backup    # Create backup at specific location

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Detect docker compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Load environment
if [ -f .env.prod ]; then
    set -a
    source .env.prod
    set +a
else
    print_warning ".env.prod not found, using defaults"
    POSTGRES_USER="postgres"
    POSTGRES_DB="docuseal_production"
fi

# Backup directory
BACKUP_BASE="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

print_info "Starting backup to: $BACKUP_DIR"

# Backup PostgreSQL
print_info "Backing up PostgreSQL database..."
$DOCKER_COMPOSE -f docker-compose.prod.yml --env-file .env.prod exec -T postgres pg_dump \
    -U "${POSTGRES_USER:-postgres}" \
    -d "${POSTGRES_DB:-docuseal_production}" \
    --clean --if-exists \
    > "$BACKUP_DIR/database.sql"

gzip "$BACKUP_DIR/database.sql"
print_info "Database backup completed: database.sql.gz"

# Backup DocuSeal files
print_info "Backing up DocuSeal files..."
docker run --rm \
    -v docuseal_docuseal_data:/data:ro \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine \
    tar czf /backup/docuseal_files.tar.gz -C /data .

print_info "Files backup completed: docuseal_files.tar.gz"

# Backup Redis (optional)
print_info "Backing up Redis data..."
docker run --rm \
    -v docuseal_redis_data:/data:ro \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine \
    tar czf /backup/redis_data.tar.gz -C /data .

print_info "Redis backup completed: redis_data.tar.gz"

# Create backup info file
cat > "$BACKUP_DIR/backup_info.txt" <<EOF
Backup Information
==================
Date: $(date)
Hostname: $(hostname)
App Host: ${APP_HOST:-unknown}

Files:
- database.sql.gz (PostgreSQL dump)
- docuseal_files.tar.gz (Uploaded documents)
- redis_data.tar.gz (Redis data)

To restore:
1. Stop services: docker compose -f docker-compose.prod.yml down
2. Restore database: gunzip < database.sql.gz | docker compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d docuseal_production
3. Restore files: tar xzf docuseal_files.tar.gz -C /path/to/docuseal/volume
4. Start services: docker compose -f docker-compose.prod.yml up -d
EOF

# Calculate sizes
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

print_info ""
print_info "=========================================="
print_info "Backup completed successfully!"
print_info "=========================================="
print_info ""
print_info "Backup location: $BACKUP_DIR"
print_info "Total size: $TOTAL_SIZE"
print_info ""
print_info "Files:"
ls -lh "$BACKUP_DIR"
print_info ""
print_info "To restore this backup, see: $BACKUP_DIR/backup_info.txt"
print_info ""

# Optional: Keep only last N backups
KEEP_BACKUPS=7
if [ -d "$BACKUP_BASE" ]; then
    BACKUP_COUNT=$(ls -1d "$BACKUP_BASE"/backup_* 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
        print_info "Removing old backups (keeping last $KEEP_BACKUPS)..."
        ls -1dt "$BACKUP_BASE"/backup_* | tail -n +$((KEEP_BACKUPS + 1)) | xargs rm -rf
    fi
fi

print_info "Backup process completed!"
