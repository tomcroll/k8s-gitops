#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="tomcroll"  # Replace with your Docker Hub username
APP_NAME="hello-app"
APP_VERSION=$(date +%Y%m%d-%H%M%S)  # Using timestamp as version
DOCKER_IMAGE="${DOCKER_USERNAME}/${APP_NAME}:${APP_VERSION}"
DOCKER_IMAGE_LATEST="${DOCKER_USERNAME}/${APP_NAME}:latest"
APP_DIR="/Users/tcroll/Developer/work/active/k8s-gitops/apps/dev/hello-app"
K8S_DIR="${APP_DIR}/k8s"

# Function to print with color
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ $1"
    else
        print_message "$RED" "✗ $1"
        exit 1
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_message "$RED" "Error: Docker is not running"
    exit 1
fi

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    print_message "$YELLOW" "Starting Minikube..."
    minikube start
    check_status "Minikube started"
fi

# Build Docker image
print_message "$YELLOW" "Building Docker image..."
docker build -t $DOCKER_IMAGE -t $DOCKER_IMAGE_LATEST $APP_DIR
check_status "Docker image built"

# Push Docker images
print_message "$YELLOW" "Pushing Docker images..."
docker push $DOCKER_IMAGE
check_status "Versioned image pushed"
docker push $DOCKER_IMAGE_LATEST
check_status "Latest image pushed"

# Update Kubernetes deployment with new image
print_message "$YELLOW" "Updating deployment manifest..."
sed -i.bak "s|image: ${DOCKER_USERNAME}/${APP_NAME}:.*|image: ${DOCKER_IMAGE}|" "${K8S_DIR}/deployment.yaml"
check_status "Deployment manifest updated"

# Commit and push changes
print_message "$YELLOW" "Committing and pushing changes..."
cd $(dirname "${K8S_DIR}")
git add "${K8S_DIR}/deployment.yaml"
git commit -m "Update ${APP_NAME} image to ${APP_VERSION}"
git push
check_status "Changes pushed to Git"

# Wait for ArgoCD to sync
print_message "$YELLOW" "Waiting for ArgoCD to sync..."
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME} -n ${APP_NAME}
check_status "Application deployed"

# Get application URL
print_message "$YELLOW" "Setting up port forwarding..."
kubectl port-forward svc/${APP_NAME} -n ${APP_NAME} 8081:80 > /dev/null 2>&1 &
PF_PID=$!
check_status "Port forwarding started"

print_message "$GREEN" "Deployment completed successfully!"
echo "Application is available at: http://localhost:8081"
echo "Image version: ${APP_VERSION}"
echo "To stop port forwarding, run: kill $PF_PID"

# Create a deployment record
DEPLOY_LOG="${APP_DIR}/deployments.log"
echo "[$(date)] Deployed version ${APP_VERSION}" >> $DEPLOY_LOG
echo "Image: ${DOCKER_IMAGE}" >> $DEPLOY_LOG
echo "----------------------------------------" >> $DEPLOY_LOG 