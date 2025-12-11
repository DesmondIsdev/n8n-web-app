# n8n Web App

## Project Overview
This is a PHP-based order management web application hosted on InfinityFree. It provides a simple interface for customers to place orders and includes an API for retrieving and processing orders, designed to integrate with n8n automation workflows.

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Git installed
- 2GB RAM minimum
- 5GB disk space

### Running Locally

```bash
# Clone the repository
git clone <repository-url>
cd n8n-web-app

# Set up environment
cp .env.example .env

# Start the application
docker-compose up -d

# Access the application
# Web App: http://localhost:8080
# phpMyAdmin: http://localhost:8081
```

### Running Tests

```bash
# Check PHP syntax
find htdocs -name "*.php" -exec php -l {} \;

# Test database connection
docker-compose exec web php /var/www/html/test_db.php
```

### Stopping the Application

```bash
docker-compose down
```

## Project Structure

```
/
├── htdocs/                   # Web root directory
│   ├── index.php            # Main order form page
│   ├── index2.html          # Alternative/secondary page
│   ├── insert_order.php     # Processes order submissions
│   ├── db.php               # Database configuration (env-aware)
│   ├── test_db.php          # Database connection test
│   └── api/                 # API endpoints
│       ├── get_orders.php   # Retrieve orders
│       └── mark_processed.php # Mark orders as processed
├── Dockerfile               # Docker container definition
├── docker-compose.yml       # Multi-container orchestration
├── .dockerignore            # Docker build exclusions
├── Jenkinsfile              # CI/CD pipeline configuration
├── .env.example             # Environment variables template
├── .htaccess                # Apache configuration
└── if0_40626529_n8n.sql     # Database schema/backup
```

## Technology Stack

- **Backend**: PHP 8.2
- **Database**: MySQL 8.0
- **Server**: Apache (with .htaccess configuration)
- **Integration**: n8n workflow automation
- **Containerization**: Docker & Docker Compose
- **CI/CD**: Jenkins
- **Container Registry**: Docker Hub (configurable)

## Database Configuration

### Production (InfinityFree)
**Host**: sql206.infinityfree.com
**Database**: if0_40626529_n8n
**User**: if0_40626529

### Local Development (Docker)
**Host**: localhost (or `db` container name)
**Port**: 3306
**Database**: n8n_orders
**User**: n8n_user

The database connection is configured in `htdocs/db.php` using PDO with UTF-8 character set support and environment variable support for flexible deployment.

## Features

### Customer-Facing
- Order submission form (`index.php`)
- Fields: Name, Email, Product/Service, Phone, Comments

### API Endpoints
Located in `htdocs/api/`:
- `get_orders.php` - Retrieve orders from database
- `mark_processed.php` - Update order status to processed

### Order Processing Flow
1. Customer fills out form on `index.php`
2. Form submits to `insert_order.php`
3. Order stored in MySQL database
4. n8n can poll `api/get_orders.php` for new orders
5. After processing, n8n calls `api/mark_processed.php`

## Development Guidelines

### Security Considerations
- Database credentials are currently stored in `db.php` (consider environment variables for production)
- API endpoints should implement authentication for production use
- Input validation should be implemented on all form submissions
- Use prepared statements (PDO) to prevent SQL injection

### Coding Standards
- Use UTF-8 encoding for all files
- Follow PSR-12 coding standards for PHP
- Use PDO for all database operations
- Enable error reporting during development
- Disable error display in production

### Common Tasks

#### Local Development with Docker

**Start the application**:
```bash
# Copy environment file
cp .env.example .env

# Start all services (web, database, phpMyAdmin)
docker-compose up -d

# View logs
docker-compose logs -f
```

**Access services**:
- Web application: http://localhost:8080
- phpMyAdmin: http://localhost:8081
- MySQL: localhost:3306

**Stop the application**:
```bash
docker-compose down
```

**Rebuild after changes**:
```bash
docker-compose up -d --build
```

#### Testing Database Connection
```bash
# Local (Docker)
docker-compose exec web php /var/www/html/test_db.php

# Direct PHP
php htdocs/test_db.php
```

#### Viewing Logs
```bash
# Docker logs
docker-compose logs web
docker-compose logs db

# Production
# Check Apache error logs on InfinityFree control panel
```

#### Database Changes
1. Update schema in MySQL via cPanel or phpMyAdmin
2. Export updated schema to `if0_40626529_n8n.sql`
3. Commit changes to git

## Docker Configuration

### Services

The application uses Docker Compose with three services:

1. **web** - PHP 8.2 with Apache
   - Port: 8080 (configurable via `WEB_PORT`)
   - Volumes: `./htdocs` mounted to `/var/www/html`
   - Environment variables for database connection

2. **db** - MySQL 8.0
   - Port: 3306 (configurable via `DB_PORT`)
   - Persistent volume: `mysql_data`
   - Auto-initializes from `if0_40626529_n8n.sql`

3. **phpmyadmin** - Database management interface
   - Port: 8081 (configurable via `PMA_PORT`)
   - Connected to MySQL service

### Environment Variables

Copy `.env.example` to `.env` and configure:

```env
WEB_PORT=8080              # Web application port
DB_HOST=db                 # Database host (container name)
DB_NAME=n8n_orders         # Database name
DB_USER=n8n_user          # Database user
DB_PASS=n8n_password      # Database password
MYSQL_ROOT_PASSWORD=root   # MySQL root password
PMA_PORT=8081             # phpMyAdmin port
```

### Docker Commands

```bash
# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f [service_name]

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build

# Execute commands in containers
docker-compose exec web bash
docker-compose exec db mysql -u root -p

# View running containers
docker-compose ps

# Remove volumes (deletes database data)
docker-compose down -v
```

## Hosting Environment

### Production (InfinityFree)
**Provider**: InfinityFree
**Control Panel**: .cpanel/
**Restrictions**:
- Free tier limitations apply
- Check InfinityFree documentation for resource limits

### Local Development (Docker)
**Platform**: Docker Desktop / Docker Engine
**Requirements**:
- Docker 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum
- 5GB disk space

## CI/CD Pipeline (Jenkins)

### Overview

The Jenkinsfile defines a complete CI/CD pipeline with the following stages:

1. **Checkout** - Clone repository and get commit info
2. **Environment Setup** - Create .env file if missing
3. **Validate** - Check file existence and PHP syntax
4. **Build Docker Image** - Create container images
5. **Test** - Run basic tests with database connection
6. **Security Scan** - Vulnerability scanning with Trivy (optional)
7. **Save Docker Image** - Export Docker image to tar.gz file (master only)
8. **Transfer to Deployment Server** - Copy image and files via SCP (master only)
9. **Load Docker Image on Server** - Import image on deployment server (master only)
10. **Deploy to Staging** - Auto-deploy non-master branches locally
11. **Deploy to Production** - Manual approval, deploy on remote server (master only)
12. **Database Migration** - Run migrations on deployment server if needed
13. **Health Check** - Verify deployment success on remote server
14. **Smoke Tests** - Test critical endpoints on remote server

### Jenkins Setup

#### Prerequisites

1. Install Jenkins with Docker support
2. Install required plugins:
   - Docker Pipeline
   - Git
   - Credentials Binding
   - Slack Notification (optional)

#### Configure Credentials

In Jenkins, add these credentials:

1. **SSH Credentials for Deployment Server** (ID: `deployment-server-ssh`)
   - Type: SSH Username with private key
   - Username: Your deployment server username
   - Private Key: Your SSH private key

2. **Slack Webhook** (optional, ID: `slack-webhook`)
   - Type: Secret text
   - For deployment notifications

#### Configure Deployment Server

Edit the Jenkinsfile environment variables:

```groovy
DEPLOY_SERVER = 'user@your-deployment-server.com'
DEPLOY_PATH = '/opt/n8n-web-app'
DEPLOY_SSH_CREDENTIALS_ID = 'deployment-server-ssh'
```

#### Create Pipeline

1. New Item → Pipeline
2. Pipeline Definition: Pipeline script from SCM
3. SCM: Git
4. Repository URL: Your git repository
5. Script Path: `Jenkinsfile`

#### Prepare Deployment Server

Before running the pipeline, prepare your deployment server:

```bash
# Install Docker and Docker Compose on deployment server
curl -fsSL https://get.docker.com | sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create deployment directory
sudo mkdir -p /opt/n8n-web-app
sudo chown $USER:$USER /opt/n8n-web-app
```

### Deployment Strategy

#### Staging Deployment (Automatic)
- Triggered on push to any branch except master
- Deploys to local Docker environment
- Runs smoke tests automatically

#### Production Deployment (Manual Approval)
- Triggered on push to master branch
- Docker image saved and transferred to deployment server via SCP
- Image loaded on deployment server
- Requires manual approval before deployment
- Deploys to remote server via SSH
- Automatic rollback on failure
- Health checks and smoke tests run on remote server

### Pipeline Customization

Edit `Jenkinsfile` to customize:

- Change deployment server address and path
- Modify deployment targets
- Add additional test stages
- Configure notifications
- Adjust health check parameters
- Change SSH credentials ID

### How It Works

1. **Build Phase**: Jenkins builds Docker image locally
2. **Save Phase**: Image exported to compressed tar.gz file
3. **Transfer Phase**: Image and application files copied to deployment server via SCP
4. **Load Phase**: Docker image imported on deployment server
5. **Deploy Phase**: Remote deployment executed via SSH
6. **Verify Phase**: Health checks and smoke tests run on remote server

## Git Workflow

**Main Branch**: master
**Current Branch**: nice-gould (worktree)

### Standard Workflow

1. Work in worktree branches
2. Commit changes
3. Create PR to master
4. Jenkins runs CI pipeline (validation, tests)
5. Review and merge PR
6. Jenkins deploys to production (with approval)

## Integration with n8n

This application is designed to integrate with n8n workflows:

1. **New Order Trigger**: n8n polls `api/get_orders.php` at intervals
2. **Process Orders**: n8n workflow handles order fulfillment
3. **Mark Complete**: n8n calls `api/mark_processed.php` after processing

## Future Improvements

- [x] Move sensitive credentials to environment variables
- [x] Dockerize the application
- [x] Create CI/CD pipeline with Jenkins
- [ ] Add authentication to API endpoints
- [ ] Implement rate limiting
- [ ] Add order status tracking for customers
- [ ] Create admin dashboard
- [ ] Add email notifications
- [ ] Implement proper error handling and logging
- [ ] Add input validation and sanitization
- [ ] Create API documentation
- [ ] Add unit tests and integration tests
- [ ] Implement Kubernetes deployment
- [ ] Add monitoring and alerting (Prometheus/Grafana)
- [ ] Set up log aggregation (ELK stack)

## Notes

- The `DO NOT UPLOAD FILES HERE` file serves as a reminder that files should be uploaded to `htdocs/`
- `.lastlogin` and `.override` are hosting provider specific files
- `.softaculous/` contains auto-installer data from the hosting provider
