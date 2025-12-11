# Jenkins Pipeline Setup Guide

This guide provides step-by-step instructions for setting up the Jenkins CI/CD pipeline for deploying the n8n web app to a remote server.

## Overview

The pipeline builds a Docker image locally on Jenkins, transfers it to a deployment server via SCP, and deploys it remotely. No Docker registry is required.

## Prerequisites

- Jenkins server with Docker installed
- Deployment server with Docker and Docker Compose installed
- SSH access from Jenkins to deployment server
- Git repository access

## Step 1: Prepare Deployment Server

SSH into your deployment server and run:

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create deployment directory
sudo mkdir -p /opt/n8n-web-app
sudo chown $USER:$USER /opt/n8n-web-app

# Verify installation
docker --version
docker-compose --version
```

## Step 2: Set Up SSH Key Authentication

On Jenkins server:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "jenkins@your-domain.com"

# Copy public key to deployment server
ssh-copy-id user@deployment-server.com

# Test SSH connection (should not prompt for password)
ssh user@deployment-server.com "echo 'SSH connection successful'"
```

## Step 3: Configure Jenkins

### Install Required Plugins

1. Go to **Manage Jenkins** > **Manage Plugins**
2. Go to **Available** tab
3. Search and install:
   - Docker Pipeline
   - Git Plugin
   - Credentials Binding Plugin
   - SSH Agent Plugin
   - Pipeline

4. Restart Jenkins after installation

### Add SSH Credentials

1. Go to **Manage Jenkins** > **Manage Credentials**
2. Click **(global)** domain
3. Click **Add Credentials**
4. Configure:
   - **Kind**: SSH Username with private key
   - **Scope**: Global
   - **ID**: `deployment-server-ssh`
   - **Description**: Deployment Server SSH Key
   - **Username**: Your deployment server username (e.g., `ubuntu`, `root`)
   - **Private Key**: Select "Enter directly"
     - Paste your private key (from `~/.ssh/id_rsa` on Jenkins server)
     - Or use "From the Jenkins master ~/.ssh"
   - **Passphrase**: Enter if your key has one

5. Click **OK**

## Step 4: Configure Jenkinsfile

Edit `Jenkinsfile` in your repository and update these variables:

```groovy
environment {
    // Docker configuration
    DOCKER_IMAGE = 'n8n-web-app'
    DOCKER_TAG = "${env.BUILD_NUMBER}"

    // Deployment server configuration
    DEPLOY_SERVER = 'ubuntu@192.168.1.100'  // Change to your server
    DEPLOY_PATH = '/opt/n8n-web-app'         // Change if needed
    DEPLOY_SSH_CREDENTIALS_ID = 'deployment-server-ssh' // Match credential ID
}
```

Example configurations:

```groovy
// Using IP address
DEPLOY_SERVER = 'ubuntu@192.168.1.100'

// Using domain name
DEPLOY_SERVER = 'deploy@app.example.com'

// Different user
DEPLOY_SERVER = 'root@server.example.com'

// Custom port (add to SSH commands)
// In this case, modify SSH commands to include: -p 2222
```

Commit and push the changes:

```bash
git add Jenkinsfile
git commit -m "Configure deployment server"
git push origin master
```

## Step 5: Create Jenkins Pipeline Job

1. Click **New Item**
2. Enter name: `n8n-web-app-pipeline`
3. Select **Pipeline**
4. Click **OK**

### Configure Pipeline

**General Section:**
- Description: `n8n Web App CI/CD Pipeline`

**Build Triggers:**
- ☑ Poll SCM
- Schedule: `H/5 * * * *` (checks every 5 minutes)
- Or use webhook for immediate builds

**Pipeline Section:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/your-username/n8n-web-app.git`
- Credentials: Add if private repository
- Branch Specifier: `*/master`
- Script Path: `Jenkinsfile`

Click **Save**

## Step 6: Configure Environment on Deployment Server

SSH to deployment server and create `.env` file:

```bash
cd /opt/n8n-web-app
cat > .env << 'EOF'
# Web Application Port
WEB_PORT=8282

# Database Configuration
DB_HOST=db
DB_NAME=n8n_orders
DB_USER=n8n_user
DB_PASS=your_secure_password_here

# MySQL Root Password
MYSQL_ROOT_PASSWORD=your_root_password_here

# PHPMyAdmin Port
PMA_PORT=8281
EOF

# Secure the .env file
chmod 600 .env
```

## Step 7: Test the Pipeline

### Manual Build

1. Go to your pipeline job
2. Click **Build Now**
3. Watch the build progress

### Monitor Build

Click on the build number (e.g., #1) and then **Console Output** to see:

```
[Pipeline] stage (Checkout)
[Pipeline] stage (Environment Setup)
[Pipeline] stage (Validate)
[Pipeline] stage (Build Docker Image)
[Pipeline] stage (Test)
[Pipeline] stage (Security Scan)
[Pipeline] stage (Save Docker Image)
[Pipeline] stage (Transfer to Deployment Server)
[Pipeline] stage (Load Docker Image on Server)
[Pipeline] stage (Deploy to Production)
Input requested: Deploy to production?
```

### Approve Production Deployment

When prompted "Deploy to production?":
1. Click the build
2. Click **Proceed** or **Abort**
3. Pipeline continues if approved

## Step 8: Verify Deployment

### On Deployment Server

```bash
# Check running containers
docker ps

# View logs
docker-compose logs -f web

# Test application
curl http://localhost:8282
```

### Access Application

From your browser or any machine:
```
http://deployment-server-ip:8282
```

## Pipeline Stages Explained

### For Master Branch

1. **Checkout** - Clone repository
2. **Environment Setup** - Create .env if missing
3. **Validate** - Check PHP syntax
4. **Build Docker Image** - Create container image
5. **Test** - Run basic tests
6. **Security Scan** - Scan for vulnerabilities (optional)
7. **Save Docker Image** - Export to tar.gz
8. **Transfer to Deployment Server** - SCP files to server
9. **Load Docker Image on Server** - Import image
10. **Deploy to Production** - Deploy with approval
11. **Database Migration** - Run migrations if needed
12. **Health Check** - Verify deployment
13. **Smoke Tests** - Test critical endpoints

### For Other Branches

1. **Checkout**
2. **Environment Setup**
3. **Validate**
4. **Build Docker Image**
5. **Test**
6. **Deploy to Staging** - Local Jenkins deployment
7. **Health Check** - Local tests
8. **Smoke Tests** - Local endpoint tests

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH from Jenkins server
ssh -v user@deployment-server.com

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Check known_hosts
ssh-keyscan deployment-server.com >> ~/.ssh/known_hosts
```

### Docker Permission Issues

On deployment server:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again
# Or run:
newgrp docker

# Test
docker ps
```

### Build Fails at Transfer Stage

Check:
1. SSH credentials are correct in Jenkins
2. Deployment server is reachable
3. Deployment path exists and has correct permissions
4. User has write permissions to deployment path

```bash
# On Jenkins server
ssh user@deployment-server.com "mkdir -p /opt/n8n-web-app && ls -la /opt/n8n-web-app"
```

### Build Fails at Load Image Stage

On deployment server:
```bash
# Check Docker is running
sudo systemctl status docker

# Check disk space
df -h

# Check if tar file was transferred
ls -lh /opt/n8n-web-app/*.tar.gz
```

### Deployment Fails

On deployment server:
```bash
cd /opt/n8n-web-app

# Check logs
docker-compose logs

# Check containers
docker-compose ps

# Restart
docker-compose down
docker-compose up -d
```

## Webhook Configuration (Optional)

For automatic builds on git push:

### GitHub

1. Go to repository **Settings** > **Webhooks**
2. Click **Add webhook**
3. Configure:
   - Payload URL: `http://jenkins-server:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event
4. Click **Add webhook**

### GitLab

1. Go to **Settings** > **Webhooks**
2. Configure:
   - URL: `http://jenkins-server:8080/project/n8n-web-app-pipeline`
   - Trigger: Push events
3. Click **Add webhook**

## Security Best Practices

1. **Use SSH Keys**: Never use passwords for SSH authentication
2. **Restrict SSH Access**: Use firewall rules to allow Jenkins IP only
3. **Secure .env File**: Set permissions to 600
4. **Use Strong Passwords**: For database and other services
5. **Enable HTTPS**: Use reverse proxy with SSL
6. **Regular Updates**: Keep Jenkins, Docker, and plugins updated
7. **Backup Regularly**: Automate backups of database and configs
8. **Monitor Logs**: Set up log aggregation and monitoring
9. **Limit Jenkins User**: Use dedicated user with minimal permissions
10. **Enable Jenkins Security**: Configure authentication and authorization

## Automated Deployment Workflow

```
Developer pushes code
        ↓
GitHub/GitLab webhook triggers Jenkins
        ↓
Jenkins checks out code
        ↓
Builds Docker image locally
        ↓
Runs tests
        ↓
Saves image to tar.gz
        ↓
Transfers to deployment server via SCP
        ↓
Loads image on deployment server
        ↓
Waits for manual approval (master branch)
        ↓
Deploys containers remotely
        ↓
Runs health checks
        ↓
Deployment complete!
```

## Maintenance

### Regular Tasks

```bash
# Update Jenkins plugins
Manage Jenkins > Manage Plugins > Updates

# Clean old Docker images on Jenkins server
docker system prune -a

# Clean old Docker images on deployment server
ssh user@deployment-server "cd /opt/n8n-web-app && docker system prune -a"

# Backup deployment
ssh user@deployment-server "cd /opt/n8n-web-app && tar czf backup.tar.gz htdocs/ .env docker-compose.yml"
```

### View Pipeline Logs

```bash
# On deployment server
cd /opt/n8n-web-app

# Web application logs
docker-compose logs -f web

# Database logs
docker-compose logs -f db

# All logs
docker-compose logs -f
```

## Support

For issues:
- Check [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment guide
- Review [CLAUDE.MD](CLAUDE.MD) for comprehensive documentation
- Check Jenkins console output for error messages
- Review deployment server logs

## Additional Resources

- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Docker Documentation](https://docs.docker.com/)
- [SSH Configuration Guide](https://www.ssh.com/academy/ssh)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
