# Troubleshooting Guide

## Common Issues and Solutions

### 403 Forbidden Error

**Symptom**: "Forbidden - You don't have permission to access this resource"

**Causes & Solutions**:

#### 1. File Permissions Issue

**Check permissions inside container**:
```bash
docker-compose exec web ls -la /var/www/html
```

**Fix permissions**:
```bash
docker-compose exec web chown -R www-data:www-data /var/www/html
docker-compose exec web find /var/www/html -type d -exec chmod 755 {} \;
docker-compose exec web find /var/www/html -type f -exec chmod 644 {} \;
docker-compose restart web
```

#### 2. Apache Configuration Issue

**Check Apache configuration**:
```bash
docker-compose exec web apache2ctl -S
```

**Verify .htaccess is being read**:
```bash
docker-compose exec web cat /var/www/html/.htaccess
```

**Rebuild container with fixed configuration**:
```bash
docker-compose down
docker-compose up -d --build
```

#### 3. SELinux Issues (if on RHEL/CentOS)

**Temporarily disable SELinux**:
```bash
sudo setenforce 0
```

**Or fix SELinux contexts**:
```bash
sudo chcon -Rt svirt_sandbox_file_t /path/to/n8n-web-app
```

#### 4. Volume Mount Permissions

**Check if volume is mounted correctly**:
```bash
docker-compose exec web pwd
docker-compose exec web ls -la
```

**Remove and recreate volumes**:
```bash
docker-compose down -v
docker-compose up -d
```

### Database Connection Failed

**Symptom**: "DB connection failed" or PDO errors

**Solutions**:

#### 1. Check Database is Running

```bash
docker-compose ps
docker-compose logs db
```

#### 2. Verify Environment Variables

```bash
docker-compose exec web env | grep DB_
```

#### 3. Test Database Connection

```bash
docker-compose exec web php -r "new PDO('mysql:host=db;dbname=n8n_orders', 'n8n_user', 'n8n_password'); echo 'Connection successful';"
```

#### 4. Check Database Logs

```bash
docker-compose logs db | tail -50
```

#### 5. Restart Database

```bash
docker-compose restart db
# Wait for database to be ready
sleep 10
docker-compose restart web
```

### Container Won't Start

**Symptom**: Container exits immediately or won't start

**Solutions**:

#### 1. Check Container Logs

```bash
docker-compose logs web
docker-compose logs db
```

#### 2. Check Port Conflicts

```bash
# Check if ports are already in use
lsof -i :8282
lsof -i :3306

# Or on Linux
netstat -tuln | grep 8282
netstat -tuln | grep 3306
```

**Fix**: Change ports in `.env`:
```env
WEB_PORT=9090
DB_PORT=3307
PMA_PORT=9091
```

#### 3. Remove and Recreate

```bash
docker-compose down -v
docker system prune -f
docker-compose up -d --build
```

### Network Errors in Jenkins

**Symptom**: "network n8n-web-app_n8n-network not found"

**Solution**: Already fixed in Jenkinsfile with project name flag

```bash
docker-compose -p n8n-web-app up -d
```

### Permission Denied Errors

**Symptom**: Cannot write to files or logs

**Solutions**:

#### 1. Fix Container Permissions

```bash
docker-compose exec web chown -R www-data:www-data /var/www/html
docker-compose exec web chmod -R 755 /var/www/html
```

#### 2. Fix Host Permissions

```bash
sudo chown -R $USER:$USER htdocs/
chmod -R 755 htdocs/
```

### Deployment Fails

**Symptom**: Jenkins deployment fails or times out

**Solutions**:

#### 1. Check SSH Connection

```bash
ssh root@your-deployment-server "echo 'SSH works'"
```

#### 2. Check Deployment Server Disk Space

```bash
ssh root@your-deployment-server "df -h"
```

#### 3. Check Docker on Deployment Server

```bash
ssh root@your-deployment-server "docker ps"
ssh root@your-deployment-server "docker-compose version"
```

#### 4. Manual Deployment Test

```bash
# SSH to deployment server
ssh root@your-deployment-server

# Navigate to deployment directory
cd n8n-web-app

# Check files
ls -la

# Try manual deploy
docker-compose down
docker-compose up -d

# Check logs
docker-compose logs -f
```

### Image Transfer Fails

**Symptom**: SCP transfer fails or times out

**Solutions**:

#### 1. Check Network Connectivity

```bash
ping deployment-server
ssh root@deployment-server "echo 'reachable'"
```

#### 2. Check Disk Space on Both Servers

```bash
# On Jenkins server
df -h

# On deployment server
ssh root@deployment-server "df -h"
```

#### 3. Transfer Manually to Debug

```bash
# Build and save image
docker save n8n-web-app:latest -o test.tar
gzip test.tar

# Transfer
scp test.tar.gz root@deployment-server:/tmp/

# Load on server
ssh root@deployment-server "cd /tmp && gunzip test.tar.gz && docker load -i test.tar"
```

### Health Check Fails

**Symptom**: curl health checks fail after deployment

**Solutions**:

#### 1. Check if Container is Running

```bash
ssh root@deployment-server "docker ps"
```

#### 2. Check Container Logs

```bash
ssh root@deployment-server "cd n8n-web-app && docker-compose logs web"
```

#### 3. Check Port Binding

```bash
ssh root@deployment-server "netstat -tuln | grep 8282"
```

#### 4. Test Manually

```bash
ssh root@deployment-server "curl -v http://localhost:8282"
```

#### 5. Check .env Configuration

```bash
ssh root@deployment-server "cat n8n-web-app/.env"
```

### Branch Detection Not Working

**Symptom**: Jenkins runs wrong stages (staging vs production)

**Solution**: Already fixed with explicit branch detection

**Verify**:
- Check Jenkins console output for:
  ```
  Git Branch: master
  Is Master: true
  ```

## Quick Fixes

### Complete Reset

```bash
# Stop everything
docker-compose down -v

# Remove all containers
docker rm -f $(docker ps -aq)

# Remove all images
docker rmi -f $(docker images -q)

# Clean system
docker system prune -af --volumes

# Start fresh
docker-compose up -d --build
```

### Force Rebuild

```bash
docker-compose build --no-cache
docker-compose up -d --force-recreate
```

### View All Logs

```bash
# Real-time logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs --tail=100 web
```

### Check Environment

```bash
# List all environment variables in container
docker-compose exec web env

# Check specific variable
docker-compose exec web env | grep DB_HOST
```

### Test PHP

```bash
# Check PHP version
docker-compose exec web php -v

# Check PHP modules
docker-compose exec web php -m

# Test PHP syntax
docker-compose exec web find /var/www/html -name "*.php" -exec php -l {} \;
```

## Debugging Commands

### Container Information

```bash
# Container details
docker inspect <container_name>

# Container stats
docker stats

# Container processes
docker-compose top
```

### Network Debugging

```bash
# List networks
docker network ls

# Inspect network
docker network inspect n8n-web-app_n8n-network

# Test network connectivity
docker-compose exec web ping db
docker-compose exec web nc -zv db 3306
```

### Database Debugging

```bash
# Access MySQL CLI
docker-compose exec db mysql -u root -pn8nroot

# Show databases
docker-compose exec db mysql -u root -pn8nroot -e "SHOW DATABASES;"

# Show tables
docker-compose exec db mysql -u root -pn8nroot n8n_orders -e "SHOW TABLES;"

# Query data
docker-compose exec db mysql -u root -pn8nroot n8n_orders -e "SELECT * FROM orders LIMIT 5;"
```

## Getting Help

If issues persist:

1. Check container logs: `docker-compose logs`
2. Check Jenkins console output
3. Verify all environment variables are set correctly
4. Ensure Docker and Docker Compose are up to date
5. Check system resources (CPU, RAM, disk space)

## Useful Links

- [Docker Documentation](https://docs.docker.com/)
- [PHP Docker Official Images](https://hub.docker.com/_/php)
- [Apache HTTP Server Documentation](https://httpd.apache.org/docs/)
- [MySQL Docker Documentation](https://hub.docker.com/_/mysql)
