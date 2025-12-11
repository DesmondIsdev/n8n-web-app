# Deployment Guide

This guide covers deploying the n8n Web App using Docker and Jenkins.

## Table of Contents

1. [Local Development Setup](#local-development-setup)
2. [Jenkins CI/CD Setup](#jenkins-cicd-setup)
3. [Production Deployment](#production-deployment)
4. [Troubleshooting](#troubleshooting)

## Local Development Setup

### 1. Prerequisites

Ensure you have installed:
- Docker 20.10 or higher
- Docker Compose 2.0 or higher
- Git

### 2. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd n8n-web-app

# Create environment file
cp .env.example .env

# Edit .env with your preferred settings (optional)
nano .env
```

### 3. Start the Application

```bash
# Start all services in detached mode
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Verify Installation

```bash
# Test web application
curl http://localhost:8080

# Test API endpoint
curl http://localhost:8080/api/get_orders.php

# Access phpMyAdmin
open http://localhost:8081
```

### 5. Stop the Application

```bash
# Stop services (keeps data)
docker-compose down

# Stop and remove volumes (deletes data)
docker-compose down -v
```

## Jenkins CI/CD Setup

### 1. Install Jenkins

#### Option A: Using Docker

```bash
docker run -d \
  --name jenkins \
  -p 8082:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

#### Option B: Native Installation

Follow official Jenkins installation guide for your platform:
https://www.jenkins.io/doc/book/installing/

### 2. Install Required Plugins

1. Access Jenkins at http://localhost:8082
2. Navigate to: Manage Jenkins > Manage Plugins
3. Install these plugins:
   - Docker Pipeline
   - Git Plugin
   - Credentials Binding Plugin
   - Slack Notification Plugin (optional)
   - Pipeline

### 3. Configure Docker Access

If running Jenkins in Docker:

```bash
# Give Jenkins permission to use Docker
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

### 4. Add Credentials

1. Navigate to: Manage Jenkins > Manage Credentials
2. Click "(global)" domain
3. Click "Add Credentials"

#### SSH Credentials for Deployment Server

- Kind: SSH Username with private key
- Scope: Global
- ID: `deployment-server-ssh`
- Description: Deployment Server SSH Access
- Username: Your server username
- Private Key: Enter directly or from file
  - If using key file: Select "Enter directly" and paste your private key
  - Or upload your SSH private key file

### 5. Configure Deployment Server Details

Edit the Jenkinsfile to set your deployment server details:

```groovy
environment {
    DEPLOY_SERVER = 'user@your-deployment-server.com'
    DEPLOY_PATH = '/opt/n8n-web-app'
    DEPLOY_SSH_CREDENTIALS_ID = 'deployment-server-ssh'
}
```

### 6. Prepare Deployment Server

SSH into your deployment server and prepare it:

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create deployment directory
sudo mkdir -p /opt/n8n-web-app
sudo chown $USER:$USER /opt/n8n-web-app
```

### 7. Create Pipeline Job

1. Click "New Item"
2. Enter job name: `n8n-web-app-pipeline`
3. Select "Pipeline"
4. Click "OK"

#### Configure Pipeline

1. Under "Pipeline" section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your git repository URL
   - Credentials: Add your git credentials if private
   - Branch: */master (or your branch)
   - Script Path: `Jenkinsfile`

2. Under "Build Triggers":
   - Check "GitHub hook trigger for GITScm polling" (if using GitHub)
   - Or check "Poll SCM" with schedule: `H/5 * * * *` (every 5 minutes)

3. Click "Save"

### 8. Test the Pipeline

1. Click "Build Now"
2. Monitor the build in "Console Output"
3. Verify all stages pass successfully

### 9. Configure Webhooks (Optional)

For automatic builds on git push:

#### GitHub

1. Go to your repository settings
2. Click "Webhooks" > "Add webhook"
3. Payload URL: `http://your-jenkins-url/github-webhook/`
4. Content type: application/json
5. Select "Just the push event"
6. Click "Add webhook"

#### GitLab

1. Go to Settings > Webhooks
2. URL: `http://your-jenkins-url/project/n8n-web-app-pipeline`
3. Trigger: Push events
4. Click "Add webhook"

## Production Deployment

### Option 1: Direct Docker Deployment

#### 1. Prepare Production Server

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 2. Deploy Application

```bash
# Clone repository
git clone <repository-url>
cd n8n-web-app

# Create production environment file
cp .env.example .env

# Edit with production values
nano .env
# Update DB credentials, ports, etc.

# Start services
docker-compose up -d

# Verify deployment
curl http://localhost:8080
```

#### 3. Configure Reverse Proxy (NGINX)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 4. Enable SSL (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal is configured automatically
```

### Option 2: Jenkins Automated Deployment

The Jenkinsfile includes automated deployment stages:

1. **Staging**: Automatic on push to non-master branches
2. **Production**: Manual approval required for master branch

#### Deployment Flow

```
Push to Git → Jenkins Build → Tests → Build Image →
Manual Approval → Deploy → Health Checks → Complete
```

#### Customize Deployment Target

Edit `Jenkinsfile` to change deployment target:

```groovy
stage('Deploy to Production') {
    steps {
        sh '''
            # SSH to production server
            ssh user@production-server << 'EOF'
            cd /path/to/app
            docker-compose pull
            docker-compose up -d
            EOF
        '''
    }
}
```

## Troubleshooting

### Issue: Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or change port in .env
echo "WEB_PORT=9090" >> .env
docker-compose up -d
```

### Issue: Database Connection Failed

```bash
# Check database logs
docker-compose logs db

# Verify database is running
docker-compose ps

# Test connection
docker-compose exec web php /var/www/html/test_db.php

# Restart database
docker-compose restart db
```

### Issue: Permission Denied

```bash
# Fix file permissions
sudo chown -R $USER:$USER .

# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock
```

### Issue: Container Won't Start

```bash
# View detailed logs
docker-compose logs --tail=100 web

# Remove old containers
docker-compose down
docker-compose up -d --force-recreate

# Check disk space
df -h
```

### Issue: Jenkins Can't Access Docker

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Or in Docker
docker restart jenkins
```

### Issue: Build Fails in Jenkins

1. Check console output for errors
2. Verify Docker is accessible: `docker ps`
3. Check credentials are configured correctly
4. Ensure Git repository is accessible
5. Verify Jenkinsfile syntax

### Database Migration Issues

```bash
# Backup current database
docker-compose exec db mysqldump -u root -p n8n_orders > backup.sql

# Import fresh schema
docker-compose exec -T db mysql -u root -p n8n_orders < if0_40626529_n8n.sql

# Restore backup if needed
docker-compose exec -T db mysql -u root -p n8n_orders < backup.sql
```

## Performance Optimization

### 1. Enable PHP OPcache

Add to Dockerfile:

```dockerfile
RUN docker-php-ext-install opcache
```

### 2. Configure MySQL Performance

Add to docker-compose.yml under `db` service:

```yaml
command: --default-authentication-plugin=mysql_native_password --max-connections=1000
```

### 3. Add Redis Caching

Add Redis service to docker-compose.yml:

```yaml
redis:
  image: redis:alpine
  ports:
    - "6379:6379"
```

## Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web

# Last 100 lines
docker-compose logs --tail=100 web
```

### Resource Usage

```bash
# Container stats
docker stats

# Disk usage
docker system df

# Clean up unused resources
docker system prune -a
```

## Backup and Restore

### Backup

```bash
# Backup database
docker-compose exec db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME} > backup_$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v n8n-web-app_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_backup.tar.gz /data
```

### Restore

```bash
# Restore database
docker-compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME} < backup_20231209.sql

# Restore volumes
docker run --rm -v n8n-web-app_mysql_data:/data -v $(pwd):/backup alpine tar xzf /backup/mysql_backup.tar.gz -C /
```

## Security Best Practices

1. Change all default passwords in `.env`
2. Use strong passwords (16+ characters)
3. Enable HTTPS in production
4. Implement API authentication
5. Regular security updates: `docker-compose pull`
6. Restrict database access to application only
7. Enable firewall rules
8. Regular backups
9. Monitor logs for suspicious activity
10. Keep Jenkins and plugins updated

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [PHP Docker Images](https://hub.docker.com/_/php)
- [MySQL Docker Images](https://hub.docker.com/_/mysql)

## Support

For issues and questions:
- Check [CLAUDE.MD](CLAUDE.MD) for comprehensive documentation
- Review [README.md](README.md) for quick reference
- Open an issue on GitHub
