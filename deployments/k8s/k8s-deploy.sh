#!/bin/bash
# ============================================================
# Secure Enterprise Chat - Kubernetes Deployment Script
# Usage: ./k8s-deploy.sh [command] [environment]
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR"
BASE_DIR="$K8S_DIR/base"
OVERLAYS_DIR="$K8S_DIR/overlays"

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed."
        exit 1
    fi
    
    if ! command -v kustomize &> /dev/null; then
        log_warning "kustomize not found, using kubectl kustomize instead."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    log_success "Prerequisites met."
}

# Build and preview manifests
preview() {
    local env="${1:-development}"
    log_info "Previewing manifests for $env environment..."
    
    if [ -d "$OVERLAYS_DIR/$env" ]; then
        kubectl kustomize "$OVERLAYS_DIR/$env"
    else
        kubectl kustomize "$BASE_DIR"
    fi
}

# Deploy to cluster
deploy() {
    local env="${1:-development}"
    log_info "Deploying to $env environment..."
    
    local target_dir="$BASE_DIR"
    if [ -d "$OVERLAYS_DIR/$env" ]; then
        target_dir="$OVERLAYS_DIR/$env"
    fi
    
    # Apply manifests
    kubectl apply -k "$target_dir"
    
    log_success "Deployment initiated."
    log_info "Waiting for rollout..."
    
    # Get the namespace
    local ns="sec-chat"
    if [ "$env" = "development" ]; then
        ns="sec-chat-dev"
    elif [ "$env" = "production" ]; then
        ns="sec-chat-prod"
    fi
    
    # Wait for deployment
    kubectl rollout status deployment/${env}-auth-service -n "$ns" --timeout=300s || true
    
    log_success "Deployment complete."
}

# Delete deployment
delete() {
    local env="${1:-development}"
    log_warning "This will delete the $env deployment. Are you sure? (y/N)"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        exit 0
    fi
    
    local target_dir="$BASE_DIR"
    if [ -d "$OVERLAYS_DIR/$env" ]; then
        target_dir="$OVERLAYS_DIR/$env"
    fi
    
    log_info "Deleting $env deployment..."
    kubectl delete -k "$target_dir" || true
    
    log_success "Deployment deleted."
}

# Check status
status() {
    local env="${1:-development}"
    local ns="sec-chat"
    
    if [ "$env" = "development" ]; then
        ns="sec-chat-dev"
    elif [ "$env" = "production" ]; then
        ns="sec-chat-prod"
    fi
    
    log_info "Status for namespace: $ns"
    echo ""
    
    log_info "Pods:"
    kubectl get pods -n "$ns" -o wide
    echo ""
    
    log_info "Services:"
    kubectl get svc -n "$ns"
    echo ""
    
    log_info "Ingress:"
    kubectl get ingress -n "$ns"
    echo ""
    
    log_info "PVCs:"
    kubectl get pvc -n "$ns"
}

# View logs
logs() {
    local env="${1:-development}"
    local component="${2:-auth-service}"
    local ns="sec-chat"
    
    if [ "$env" = "development" ]; then
        ns="sec-chat-dev"
    elif [ "$env" = "production" ]; then
        ns="sec-chat-prod"
    fi
    
    kubectl logs -f -l app.kubernetes.io/name="$component" -n "$ns" --all-containers
}

# Port forward for local access
port_forward() {
    local env="${1:-development}"
    local ns="sec-chat"
    
    if [ "$env" = "development" ]; then
        ns="sec-chat-dev"
    elif [ "$env" = "production" ]; then
        ns="sec-chat-prod"
    fi
    
    log_info "Port forwarding auth-service to localhost:8081..."
    kubectl port-forward svc/${env}-auth-service-svc 8081:8081 -n "$ns"
}

# Scale deployment
scale() {
    local env="${1:-development}"
    local replicas="${2:-3}"
    local ns="sec-chat"
    
    if [ "$env" = "development" ]; then
        ns="sec-chat-dev"
    elif [ "$env" = "production" ]; then
        ns="sec-chat-prod"
    fi
    
    log_info "Scaling auth-service to $replicas replicas..."
    kubectl scale deployment/${env}-auth-service --replicas="$replicas" -n "$ns"
    
    log_success "Scaling initiated."
}

# Show help
show_help() {
    echo "Secure Enterprise Chat - Kubernetes Deployment Script"
    echo ""
    echo "Usage: $0 <command> [environment]"
    echo ""
    echo "Commands:"
    echo "  preview [env]     Preview generated manifests"
    echo "  deploy [env]      Deploy to cluster"
    echo "  delete [env]      Delete deployment"
    echo "  status [env]      Show deployment status"
    echo "  logs [env] [svc]  View service logs"
    echo "  port-forward      Port forward to local"
    echo "  scale [env] [n]   Scale deployment"
    echo "  help              Show this help"
    echo ""
    echo "Environments:"
    echo "  development (default)"
    echo "  production"
    echo ""
    echo "Examples:"
    echo "  $0 preview development"
    echo "  $0 deploy production"
    echo "  $0 status production"
    echo "  $0 logs development auth-service"
    echo "  $0 scale production 5"
}

# Main
case "$1" in
    preview)
        check_prerequisites
        preview "$2"
        ;;
    deploy)
        check_prerequisites
        deploy "$2"
        ;;
    delete)
        check_prerequisites
        delete "$2"
        ;;
    status)
        check_prerequisites
        status "$2"
        ;;
    logs)
        check_prerequisites
        logs "$2" "$3"
        ;;
    port-forward)
        check_prerequisites
        port_forward "$2"
        ;;
    scale)
        check_prerequisites
        scale "$2" "$3"
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
