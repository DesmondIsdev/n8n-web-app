#!/bin/bash
# Fix permissions for n8n web app

echo "Fixing permissions for n8n web app..."

# Fix permissions inside running container
if docker-compose ps web | grep -q "Up"; then
    echo "Fixing permissions in running container..."
    docker-compose exec web chown -R www-data:www-data /var/www/html
    docker-compose exec web find /var/www/html -type d -exec chmod 755 {} \;
    docker-compose exec web find /var/www/html -type f -exec chmod 644 {} \;

    echo "Restarting web service..."
    docker-compose restart web

    echo "Waiting for service to be ready..."
    sleep 5

    # Test if it's working
    PORT=$(grep WEB_PORT .env 2>/dev/null | cut -d= -f2)
    PORT=${PORT:-8282}

    if curl -f http://localhost:$PORT > /dev/null 2>&1; then
        echo "✅ Success! Application is accessible on http://localhost:$PORT"
    else
        echo "❌ Application still not accessible. Check logs with: docker-compose logs web"
    fi
else
    echo "Container not running. Starting services..."
    docker-compose up -d --build

    echo "Waiting for services to start..."
    sleep 10

    # Test if it's working
    PORT=$(grep WEB_PORT .env 2>/dev/null | cut -d= -f2)
    PORT=${PORT:-8282}

    if curl -f http://localhost:$PORT > /dev/null 2>&1; then
        echo "✅ Success! Application is accessible on http://localhost:$PORT"
    else
        echo "❌ Application not accessible. Check logs with: docker-compose logs"
    fi
fi
