#!/bin/bash
# Verify deployment on server

echo "========================================="
echo "n8n Web App Deployment Verification"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Installed"
    docker --version
else
    echo -e "${RED}✗${NC} Not installed"
    exit 1
fi

echo ""

# Check Docker Compose
echo -n "Checking Docker Compose... "
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC} Installed"
    docker-compose --version
else
    echo -e "${RED}✗${NC} Not installed"
    exit 1
fi

echo ""

# Check if containers are running
echo "Checking containers..."
docker-compose ps

echo ""

# Check web container
echo -n "Web container status... "
if docker-compose ps web | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Running"
else
    echo -e "${RED}✗${NC} Not running"
    echo "Starting containers..."
    docker-compose up -d
    sleep 10
fi

echo ""

# Check files in container
echo "Checking files in container..."
echo "Files in /var/www/html:"
docker-compose exec web ls -la /var/www/html/

echo ""

# Check if index.php exists
echo -n "index.php exists... "
if docker-compose exec web test -f /var/www/html/index.php; then
    echo -e "${GREEN}✓${NC} Yes"
else
    echo -e "${RED}✗${NC} No - THIS IS THE PROBLEM!"
    echo ""
    echo "Files were not copied correctly. Rebuilding..."
    docker-compose down
    docker-compose up -d --build
    sleep 15
fi

echo ""

# Check Apache config
echo "Apache configuration test..."
docker-compose exec web apache2ctl configtest

echo ""

# Get port
PORT=$(grep WEB_PORT .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-8282}

echo "Testing application on port $PORT..."

# Test localhost
echo -n "Testing http://localhost:$PORT... "
if curl -f http://localhost:$PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Accessible"
else
    echo -e "${RED}✗${NC} Not accessible"
    echo ""
    echo "Checking web container logs:"
    docker-compose logs --tail=20 web
fi

echo ""

# Test API
echo -n "Testing API endpoint... "
if curl -f http://localhost:$PORT/api/get_orders.php > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Accessible"
else
    echo -e "${YELLOW}⚠${NC} Not accessible (might need database)"
fi

echo ""

# Check database
echo -n "Database container status... "
if docker-compose ps db | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Running"

    echo -n "Database health... "
    if docker-compose exec db mysqladmin ping -h localhost -u root -pn8nroot &> /dev/null; then
        echo -e "${GREEN}✓${NC} Healthy"
    else
        echo -e "${RED}✗${NC} Not healthy"
    fi
else
    echo -e "${RED}✗${NC} Not running"
fi

echo ""
echo "========================================="
echo "Verification Complete"
echo "========================================="

# Final summary
echo ""
if curl -f http://localhost:$PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is accessible at http://localhost:$PORT${NC}"
else
    echo -e "${RED}✗ Application is NOT accessible${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check logs: docker-compose logs web"
    echo "2. Rebuild: docker-compose down && docker-compose up -d --build"
    echo "3. Check permissions: docker-compose exec web ls -la /var/www/html"
    echo "4. Check Apache: docker-compose exec web apache2ctl -S"
fi
