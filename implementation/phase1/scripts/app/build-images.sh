#!/bin/bash
# =============================================================================
# KPS-Enterprise: Docker Image Build Script
# =============================================================================
# This script builds and pushes Backend and Frontend Docker images to Docker Hub.
#
# Prerequisites:
#   - Docker installed and running
#   - Docker Hub account and access token
#   - Source code in src/Application-Code/
#
# Usage: ./build-images.sh [--backend-only | --frontend-only]
#
# Environment Variables (optional):
#   DOCKERHUB_USER   - Docker Hub username
#   DOCKERHUB_TOKEN  - Docker Hub access token
#   IMAGE_TAG        - Image tag (default: v1.0)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../../../.."
SRC_DIR="${PROJECT_ROOT}/src/Application-Code"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  KPS-Enterprise: Docker Image Build"
echo "=============================================="
echo ""

# ----------------------------------------
# Parse Arguments
# ----------------------------------------
BUILD_BACKEND=true
BUILD_FRONTEND=true

if [ "$1" = "--backend-only" ]; then
    BUILD_FRONTEND=false
elif [ "$1" = "--frontend-only" ]; then
    BUILD_BACKEND=false
fi

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running."
    exit 1
fi
log_success "Docker is available"

# Check source directories
if [ ! -d "${SRC_DIR}/backend" ]; then
    log_error "Backend source not found: ${SRC_DIR}/backend"
    exit 1
fi
if [ ! -d "${SRC_DIR}/frontend" ]; then
    log_error "Frontend source not found: ${SRC_DIR}/frontend"
    exit 1
fi
log_success "Source directories found"

# ----------------------------------------
# Docker Hub Configuration
# ----------------------------------------
echo ""
log_info "Docker Hub Configuration"

# Get Docker Hub username
if [ -z "$DOCKERHUB_USER" ]; then
    read -p "Enter Docker Hub username: " DOCKERHUB_USER
fi
if [ -z "$DOCKERHUB_USER" ]; then
    log_error "Docker Hub username is required."
    exit 1
fi

# Get Docker Hub token/password
if [ -z "$DOCKERHUB_TOKEN" ]; then
    read -sp "Enter Docker Hub access token (or password): " DOCKERHUB_TOKEN
    echo ""
fi
if [ -z "$DOCKERHUB_TOKEN" ]; then
    log_error "Docker Hub access token is required."
    exit 1
fi

# Get image tag
if [ -z "$IMAGE_TAG" ]; then
    read -p "Enter image tag (default: v1.0): " IMAGE_TAG
    IMAGE_TAG=${IMAGE_TAG:-v1.0}
fi

echo ""
log_info "Configuration:"
echo "  Docker Hub User: ${DOCKERHUB_USER}"
echo "  Image Tag:       ${IMAGE_TAG}"
echo "  Backend:         ${BUILD_BACKEND}"
echo "  Frontend:        ${BUILD_FRONTEND}"

# ----------------------------------------
# Docker Login
# ----------------------------------------
echo ""
log_info "Logging in to Docker Hub..."
echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USER}" --password-stdin

if [ $? -ne 0 ]; then
    log_error "Docker Hub login failed!"
    exit 1
fi
log_success "Docker Hub login successful"

# ----------------------------------------
# Build Backend
# ----------------------------------------
if [ "$BUILD_BACKEND" = true ]; then
    echo ""
    log_info "Building Backend Docker image..."
    
    BACKEND_IMAGE="${DOCKERHUB_USER}/kps-backend"
    
    cd "${SRC_DIR}/backend"
    
    # Build image
    docker build -t "${BACKEND_IMAGE}:${IMAGE_TAG}" .
    docker tag "${BACKEND_IMAGE}:${IMAGE_TAG}" "${BACKEND_IMAGE}:latest"
    
    log_success "Backend image built: ${BACKEND_IMAGE}:${IMAGE_TAG}"
    
    # Push image
    log_info "Pushing Backend image to Docker Hub..."
    docker push "${BACKEND_IMAGE}:${IMAGE_TAG}"
    docker push "${BACKEND_IMAGE}:latest"
    
    log_success "Backend image pushed: ${BACKEND_IMAGE}:${IMAGE_TAG}"
fi

# ----------------------------------------
# Build Frontend
# ----------------------------------------
if [ "$BUILD_FRONTEND" = true ]; then
    echo ""
    log_info "Building Frontend Docker image..."
    log_info "This may take a few minutes (npm install)..."
    
    FRONTEND_IMAGE="${DOCKERHUB_USER}/kps-frontend"
    
    cd "${SRC_DIR}/frontend"
    
    # Build image
    docker build -t "${FRONTEND_IMAGE}:${IMAGE_TAG}" .
    docker tag "${FRONTEND_IMAGE}:${IMAGE_TAG}" "${FRONTEND_IMAGE}:latest"
    
    log_success "Frontend image built: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
    
    # Push image
    log_info "Pushing Frontend image to Docker Hub..."
    docker push "${FRONTEND_IMAGE}:${IMAGE_TAG}"
    docker push "${FRONTEND_IMAGE}:latest"
    
    log_success "Frontend image pushed: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
fi

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Docker Images Build Complete!"
echo "=============================================="
echo ""
if [ "$BUILD_BACKEND" = true ]; then
    echo "Backend:  ${DOCKERHUB_USER}/kps-backend:${IMAGE_TAG}"
fi
if [ "$BUILD_FRONTEND" = true ]; then
    echo "Frontend: ${DOCKERHUB_USER}/kps-frontend:${IMAGE_TAG}"
fi
echo ""
log_info "Next Steps:"
echo "  1. Update Kubernetes manifests with Docker Hub images"
echo "  2. Deploy the application: ./deploy-app.sh"
echo ""

# Save image info
cat > "${SCRIPT_DIR}/image-info.txt" << EOF
# KPS-Enterprise Docker Images
# Generated: $(date)

DOCKERHUB_USER=${DOCKERHUB_USER}
IMAGE_TAG=${IMAGE_TAG}

BACKEND_IMAGE=${DOCKERHUB_USER}/kps-backend:${IMAGE_TAG}
FRONTEND_IMAGE=${DOCKERHUB_USER}/kps-frontend:${IMAGE_TAG}

# Pull images
docker pull ${DOCKERHUB_USER}/kps-backend:${IMAGE_TAG}
docker pull ${DOCKERHUB_USER}/kps-frontend:${IMAGE_TAG}
EOF

log_success "Image info saved to: ${SCRIPT_DIR}/image-info.txt"
