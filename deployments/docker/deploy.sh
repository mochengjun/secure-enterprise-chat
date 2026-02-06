#!/bin/bash
# ============================================================
# Secure Enterprise Chat - Deployment Script
# Usage: ./deploy.sh [command] [options]
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    log_success "All prerequisites met."
}

# Initialize environment
init() {
    log_info "Initializing environment..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_info "Creating .env file from template..."
        cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
        log_warning "Please edit $ENV_FILE and configure your environment before deploying."
        exit 0
    fi
    
    # Create necessary directories
    mkdir -p "$SCRIPT_DIR/nginx/ssl"
    mkdir -p "$SCRIPT_DIR/keys"
    
    log_success "Environment initialized."
}

# Build images
build() {
    log_info "Building Docker images..."
    
    docker compose -f "$COMPOSE_FILE" build --no-cache "$@"
    
    log_success "Images built successfully."
}

# Start services
start() {
    log_info "Starting services..."
    
    docker compose -f "$COMPOSE_FILE" up -d "$@"
    
    log_success "Services started."
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    docker compose -f "$COMPOSE_FILE" ps
}

# Stop services
stop() {
    log_info "Stopping services..."
    
    docker compose -f "$COMPOSE_FILE" down "$@"
    
    log_success "Services stopped."
}

# Restart services
restart() {
    log_info "Restarting services..."
    
    stop
    start
    
    log_success "Services restarted."
}

# View logs
logs() {
    docker compose -f "$COMPOSE_FILE" logs -f "$@"
}

# Check service status
status() {
    log_info "Service status:"
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    log_info "Health checks:"
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}"
}

# Run database migrations
migrate() {
    log_info "Running database migrations..."
    
    docker compose -f "$COMPOSE_FILE" exec auth-service /app/auth-service migrate
    
    log_success "Migrations completed."
}

# Create database backup
backup() {
    BACKUP_DIR="$SCRIPT_DIR/backups"
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
    
    mkdir -p "$BACKUP_DIR"
    
    log_info "Creating database backup..."
    
    docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_FILE"
    
    gzip "$BACKUP_FILE"
    
    log_success "Backup created: ${BACKUP_FILE}.gz"
}

# Restore database from backup
restore() {
    if [ -z "$1" ]; then
        log_error "Please provide backup file path."
        echo "Usage: $0 restore <backup_file>"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    log_warning "This will overwrite the current database. Are you sure? (y/N)"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Restore cancelled."
        exit 0
    fi
    
    log_info "Restoring database from backup..."
    
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        gunzip -c "$BACKUP_FILE" | docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB"
    else
        docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB" < "$BACKUP_FILE"
    fi
    
    log_success "Database restored."
}

# Update deployment
update() {
    log_info "Updating deployment..."
    
    # Pull latest code (if using git)
    if [ -d "$PROJECT_ROOT/.git" ]; then
        log_info "Pulling latest code..."
        git -C "$PROJECT_ROOT" pull
    fi
    
    # Rebuild and restart
    build
    restart
    
    log_success "Deployment updated."
}

# Clean up unused resources
cleanup() {
    log_info "Cleaning up unused Docker resources..."
    
    docker system prune -f
    docker volume prune -f
    
    log_success "Cleanup completed."
}

# Generate SSL certificate using Let's Encrypt
ssl_setup() {
    DOMAIN="$1"
    
    if [ -z "$DOMAIN" ]; then
        log_error "Please provide domain name."
        echo "Usage: $0 ssl-setup <domain>"
        exit 1
    fi
    
    log_info "Setting up SSL certificate for $DOMAIN..."
    
    # Create certbot directory
    mkdir -p "$SCRIPT_DIR/certbot/www"
    mkdir -p "$SCRIPT_DIR/certbot/conf"
    
    # Run certbot
    docker run --rm -it \
        -v "$SCRIPT_DIR/certbot/conf:/etc/letsencrypt" \
        -v "$SCRIPT_DIR/certbot/www:/var/www/certbot" \
        certbot/certbot certonly --webroot \
        --webroot-path=/var/www/certbot \
        -d "$DOMAIN" \
        --email "admin@$DOMAIN" \
        --agree-tos \
        --no-eff-email
    
    # Copy certificates to nginx ssl directory
    cp "$SCRIPT_DIR/certbot/conf/live/$DOMAIN/fullchain.pem" "$SCRIPT_DIR/nginx/ssl/"
    cp "$SCRIPT_DIR/certbot/conf/live/$DOMAIN/privkey.pem" "$SCRIPT_DIR/nginx/ssl/"
    cp "$SCRIPT_DIR/certbot/conf/live/$DOMAIN/chain.pem" "$SCRIPT_DIR/nginx/ssl/"
    
    log_success "SSL certificate installed for $DOMAIN"
    log_info "Remember to uncomment HTTPS configuration in nginx/conf.d/default.conf"
}

# Show help
show_help() {
    echo "Secure Enterprise Chat - Deployment Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init          Initialize environment (create .env from template)"
    echo "  build         Build Docker images"
    echo "  start         Start all services"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  status        Show service status"
    echo "  logs          View service logs (use -f for follow)"
    echo "  migrate       Run database migrations"
    echo "  backup        Create database backup"
    echo "  restore       Restore database from backup"
    echo "  update        Update deployment (pull, build, restart)"
    echo "  cleanup       Clean up unused Docker resources"
    echo "  ssl-setup     Setup SSL certificate with Let's Encrypt"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init                    # Initialize environment"
    echo "  $0 build                   # Build all images"
    echo "  $0 start                   # Start all services"
    echo "  $0 logs auth-service       # View auth-service logs"
    echo "  $0 ssl-setup example.com   # Setup SSL for domain"
}

# Main
case "$1" in
    init)
        check_prerequisites
        init
        ;;
    build)
        check_prerequisites
        shift
        build "$@"
        ;;
    start)
        check_prerequisites
        shift
        start "$@"
        ;;
    stop)
        shift
        stop "$@"
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        shift
        logs "$@"
        ;;
    migrate)
        migrate
        ;;
    backup)
        backup
        ;;
    restore)
        shift
        restore "$@"
        ;;
    update)
        update
        ;;
    cleanup)
        cleanup
        ;;
    ssl-setup)
        shift
        ssl_setup "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
