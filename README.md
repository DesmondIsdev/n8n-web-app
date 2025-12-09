# n8n Web App

A PHP-based order management web application with n8n workflow integration, fully containerized with Docker and automated CI/CD using Jenkins.

## Features

- Order submission form with customer details
- REST API endpoints for n8n integration
- MySQL database with persistent storage
- phpMyAdmin for database management
- Docker containerization for easy deployment
- Jenkins CI/CD pipeline with automated testing
- Environment-based configuration

## Quick Start

### Using Docker (Recommended)

```bash
# Clone and navigate to project
git clone <repository-url>
cd n8n-web-app

# Set up environment variables
cp .env.example .env

# Start all services
docker-compose up -d

# Access the application
# Web App: http://localhost:8080
# phpMyAdmin: http://localhost:8081
# MySQL: localhost:3306
```

## Project Structure

```
n8n-web-app/
├── htdocs/              # Application code
│   ├── index.php        # Order form
│   ├── insert_order.php # Order processing
│   ├── db.php           # Database config
│   └── api/             # API endpoints
├── Dockerfile           # Container definition
├── docker-compose.yml   # Multi-container setup
├── Jenkinsfile          # CI/CD pipeline
└── .env.example         # Environment template
```

## API Endpoints

### Get Orders
```bash
GET /api/get_orders.php
```
Returns all orders from the database.

### Mark Order as Processed
```bash
POST /api/mark_processed.php
Content-Type: application/json

{
  "order_id": 123
}
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

```env
# Web server
WEB_PORT=8080

# Database
DB_HOST=db
DB_NAME=n8n_orders
DB_USER=n8n_user
DB_PASS=n8n_password

# MySQL
MYSQL_ROOT_PASSWORD=rootpassword

# phpMyAdmin
PMA_PORT=8081
```

## Development

### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum

### Running Locally

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Rebuild after changes
docker-compose up -d --build

# Stop services
docker-compose down
```

### Testing

```bash
# PHP syntax check
find htdocs -name "*.php" -exec php -l {} \;

# Test database connection
docker-compose exec web php /var/www/html/test_db.php
```

### Database Management

Access phpMyAdmin at http://localhost:8081

- Server: db
- Username: root
- Password: (value from MYSQL_ROOT_PASSWORD)

## CI/CD Pipeline

This project includes a complete Jenkins pipeline with:

- Automated builds on push
- PHP syntax validation
- Docker image creation
- Security scanning (Trivy)
- Automated staging deployments
- Manual production approval
- Health checks and smoke tests
- Automatic rollback on failure

See [CLAUDE.MD](CLAUDE.MD) for detailed Jenkins setup instructions.

## n8n Integration

### Polling for New Orders

Configure n8n to poll the API:

1. HTTP Request node
2. Method: GET
3. URL: `http://your-domain/api/get_orders.php`
4. Schedule: Every 5 minutes (or as needed)

### Marking Orders as Processed

After processing an order:

1. HTTP Request node
2. Method: POST
3. URL: `http://your-domain/api/mark_processed.php`
4. Body: `{"order_id": {{$json["id"]}}}`

## Production Deployment

### InfinityFree Hosting

The application is currently hosted on InfinityFree:

- Host: sql206.infinityfree.com
- Database: if0_40626529_n8n

Database credentials are configured via environment variables with fallback to production values.

### Docker Deployment

For production Docker deployment:

```bash
# Pull latest images
docker-compose pull

# Deploy with production env
docker-compose -f docker-compose.yml up -d

# Verify deployment
curl http://localhost:8080
```

## Troubleshooting

### Database Connection Issues

```bash
# Check database logs
docker-compose logs db

# Test connection
docker-compose exec web php /var/www/html/test_db.php
```

### Web Server Issues

```bash
# Check web server logs
docker-compose logs web

# Restart web service
docker-compose restart web
```

### Port Conflicts

If ports 8080 or 3306 are already in use, modify `.env`:

```env
WEB_PORT=9090
DB_PORT=3307
```

## Security Considerations

- Change default passwords in `.env`
- Add authentication to API endpoints for production
- Use HTTPS in production
- Implement rate limiting
- Enable CORS restrictions
- Regular security updates

## Documentation

See [CLAUDE.MD](CLAUDE.MD) for comprehensive documentation including:

- Detailed architecture
- Development guidelines
- Jenkins setup guide
- Deployment strategies
- Troubleshooting tips

## License

[Add your license here]

## Support

For issues and questions, please open an issue on GitHub.
