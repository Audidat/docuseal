#!/bin/bash
# Production Deployment Script for Electronic Signature System
#
# This script deploys the complete stack including:
# - DocuSeal (Rails application)
# - PostgreSQL database
# - Redis
# - DSS Service (Java)
# - Caddy reverse proxy
#
# Usage:
#   cd docuseal/
#   ./deploy.sh           # Deploy/update all services (uses hybrid compose)
#   ./deploy.sh --build   # Rebuild images before deploying
#   ./deploy.sh --fresh   # Fresh deployment (removes volumes)
#   ./deploy.sh --legacy  # Use original docker-compose.prod.yml (may have Rails 8 issues)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Detect docker compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

print_info "Using Docker Compose: $DOCKER_COMPOSE"

# Determine which compose file to use
COMPOSE_FILE="docker-compose.prod-hybrid.yml"
USE_LEGACY=false
if [ ! -f .env.prod ]; then
    print_error ".env.prod file not found!"
    print_info "Please create .env.prod from .env.prod.example and configure it:"
    print_info "  cp .env.prod.example .env.prod"
    print_info "  nano .env.prod"
    exit 1
fi

# Load environment variables
set -a
source .env.prod
set +a

# Validate required environment variables
print_info "Validating configuration..."

REQUIRED_VARS=(
    "APP_HOST"
    "SECRET_KEY_BASE"
    "ENCRYPTION_KEY"
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "P12_CERT_PATH"
    "P12_PASSWORD"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

# Check if P12 certificate exists
if [ ! -f "$P12_CERT_PATH" ]; then
    print_error "P12 certificate not found at: $P12_CERT_PATH"
    print_info "Please place your certificate file and update P12_CERT_PATH in .env.prod"
    exit 1
fi

print_info "Configuration validated successfully!"

# Parse command line arguments
BUILD_FLAG=""
FRESH_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG="--build"
            print_info "Will rebuild Docker images"
            shift
            ;;
        --fresh)
            FRESH_DEPLOY=true
            print_warning "Fresh deployment will remove all data!"
            shift
            ;;
        --legacy)
            COMPOSE_FILE="docker-compose.prod.yml"
            USE_LEGACY=true
            print_warning "Using legacy docker-compose.prod.yml (may have Rails 8 issues)"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Usage: $0 [--build] [--fresh] [--legacy]"
            exit 1
            ;;
    esac
done

print_info "Using compose file: $COMPOSE_FILE"

# Fresh deployment - remove everything
if [ "$FRESH_DEPLOY" = true ]; then
    print_warning "Starting fresh deployment..."
    read -p "This will DELETE all data. Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Deployment cancelled."
        exit 0
    fi

    print_info "Stopping and removing containers..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE down -v
fi

# Pull latest images
print_info "Pulling latest images..."
$DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod pull

# Build images if requested
if [ -n "$BUILD_FLAG" ]; then
    print_info "Building Docker images..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod build --no-cache
fi

# Start services
print_info "Starting services..."
$DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod up -d $BUILD_FLAG

# Wait for services to be healthy
print_info "Waiting for services to be healthy..."
sleep 10

# Check service status
print_info "Checking service status..."
$DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod ps

# Database migrations are handled in the startup command for hybrid setup
if [ "$USE_LEGACY" = true ]; then
    print_info "Running database migrations..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod exec -T docuseal bundle exec rails db:migrate
else
    print_info "Database migrations run automatically in hybrid setup"
fi

# Show logs
print_info ""
print_info "=========================================="
print_info "Deployment completed successfully!"
print_info "=========================================="
print_info ""
print_info "Services running:"
print_info "  - DocuSeal: https://${APP_HOST}"
print_info "  - DSS Service: http://localhost:4000 (internal)"
print_info ""
print_info "Useful commands:"
print_info "  - View logs:    $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod logs -f"
print_info "  - Stop:         $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod stop"
print_info "  - Restart:      $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod restart"
print_info "  - Status:       $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod ps"
print_info ""
print_info "To view real-time logs, run:"
print_info "  $DOCKER_COMPOSE -f $COMPOSE_FILE --env-file .env.prod logs -f"
print_info ""
