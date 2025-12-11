#!/bin/bash
# Rebuild and fix the 403 error
# Run this on your deployment server

set -e

echo "========================================="
echo "Rebuilding n8n Web App"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    echo "Please run this script from the n8n-web-app directory"
    exit 1
fi

# Check if htdocs exists
if [ ! -d "htdocs" ]; then
    echo -e "${RED}Error: htdocs directory not found${NC}"
    echo "Files were not transferred correctly. Please check Jenkins deployment."
    exit 1
fi

# Check if index.php exists in htdocs
if [ ! -f "htdocs/index.php" ]; then
    echo -e "${RED}Error: htdocs/index.php not found${NC}"
    echo "Files were not transferred correctly. Please check Jenkins deployment."
    exit 1
fi

echo -e "${GREEN}✓${NC} All required files present"
echo ""

# Stop containers
echo "Stopping containers..."
docker-compose down

# Remove old images
echo "Removing old images..."
docker rmi n8n-web-app:latest 2>/dev/null || true
docker images | grep n8n-web-app | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true

# Rebuild with no cache
echo ""
echo "Rebuilding image with new Dockerfile..."
echo "(This will take a few minutes)"
echo ""
docker-compose build --no-cache

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Build successful"
else
    echo ""
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi

# Start containers
echo ""
echo "Starting containers..."
docker-compose up -d

# Wait for startup
echo "Waiting for services to start..."
sleep 15

# Verify files in container
echo ""
echo "Verifying files in container..."
docker-compose exec web ls -la /var/www/html/

# Check if index.php exists in container
echo ""
echo -n "Checking index.php in container... "
if docker-compose exec web test -f /var/www/html/index.php; then
    echo -e "${GREEN}✓${NC} Found"
else
    echo -e "${RED}✗${NC} Missing - BUILD FAILED"
    echo ""
    echo "The build completed but files were not copied correctly."
    echo "This might be a Dockerfile issue."
    exit 1
fi

# Get port
PORT=$(grep WEB_PORT .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-8282}

# Test application
echo ""
echo "Testing application on port $PORT..."
sleep 5

if curl -f http://localhost:$PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Application is accessible!"
    echo ""
    echo "========================================="
    echo -e "${GREEN}SUCCESS!${NC}"
    echo "========================================="
    echo ""
    echo "Application is running at: http://localhost:$PORT"
    echo ""
    # Show actual response
    echo "Response preview:"
    curl -s http://localhost:$PORT | head -20
else
    echo -e "${RED}✗${NC} Application not accessible"
    echo ""
    echo "Checking logs for errors..."
    docker-compose logs --tail=30 web
    echo ""
    echo -e "${YELLOW}The container is running but returning 403.${NC}"
    echo "This might be a permissions or Apache configuration issue."
    exit 1
fi
