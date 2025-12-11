pipeline {
    agent any

    environment {
        // Docker configuration
        DOCKER_IMAGE = 'n8n-web-app'
        DOCKER_TAG = "${env.BUILD_NUMBER}"

        // Application configuration
        APP_NAME = 'n8n-web-app'

        // Deployment server configuration
        DEPLOY_ADDRESS = credentials('DEV_SERVER')
        DEPLOY_SERVER = "root@${DEPLOY_ADDRESS}"
        DEPLOY_PATH = 'n8n-web-app' // Path on deployment server
        DEPLOY_SSH_CREDENTIALS_ID = credentials('ssh-credentials-comulead-test-id') // Jenkins SSH credential ID

        // Notification
        SLACK_CHANNEL = '#deployments' // Optional: configure if using Slack
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    // Detect branch name
                    env.GIT_BRANCH = sh(
                        script: "git rev-parse --abbrev-ref HEAD",
                        returnStdout: true
                    ).trim()

                    // Check if we're on master
                    env.IS_MASTER = (env.GIT_BRANCH == 'master' || env.BRANCH_NAME == 'master') ? 'true' : 'false'

                    echo "Git Branch: ${env.GIT_BRANCH}"
                    echo "Branch Name: ${env.BRANCH_NAME}"
                    echo "Is Master: ${env.IS_MASTER}"
                }
            }
        }

        stage('Environment Setup') {
            steps {
                echo 'Setting up environment...'
                sh '''
                    if [ ! -f .env ]; then
                        echo "Creating .env from .env.example"
                        cp .env.example .env
                    fi
                '''
            }
        }

        stage('Validate') {
            steps {
                echo 'Validating project files...'
                sh '''
                    # Check if required files exist
                    [ -f Dockerfile ] || { echo "Dockerfile not found"; exit 1; }
                    [ -f docker-compose.yml ] || { echo "docker-compose.yml not found"; exit 1; }
                    [ -d htdocs ] || { echo "htdocs directory not found"; exit 1; }

                    # Check critical application files in htdocs
                    echo "Checking critical application files..."
                    [ -f htdocs/index.php ] || { echo "ERROR: htdocs/index.php not found"; exit 1; }
                    [ -f htdocs/db.php ] || { echo "ERROR: htdocs/db.php not found"; exit 1; }
                    [ -f htdocs/.htaccess ] || { echo "ERROR: htdocs/.htaccess not found"; exit 1; }
                    [ -d htdocs/api ] || { echo "ERROR: htdocs/api directory not found"; exit 1; }
                    [ -f htdocs/api/get_orders.php ] || { echo "ERROR: htdocs/api/get_orders.php not found"; exit 1; }

                    # Validate PHP syntax
                    find htdocs -name "*.php" -exec php -l {} \\; || { echo "PHP syntax errors found"; exit 1; }

                    # Check file permissions
                    echo "Checking file permissions..."
                    HTACCESS_PERMS=$(stat -c %a htdocs/.htaccess 2>/dev/null || stat -f %A htdocs/.htaccess)
                    if [ "$HTACCESS_PERMS" = "644" ] || [ "$HTACCESS_PERMS" = "600" ]; then
                        echo "✓ .htaccess permissions OK: $HTACCESS_PERMS"
                    else
                        echo "WARNING: .htaccess permissions: $HTACCESS_PERMS (should be 644)"
                    fi

                    echo "✓ Validation successful"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        stage('Verify Build') {
            steps {
                echo 'Verifying Docker image contains all files...'
                sh '''
                    echo "Checking if files were copied to image..."

                    # Run container and check if index.php exists
                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} test -f /var/www/html/index.php || {
                        echo "❌ CRITICAL ERROR: index.php not found in Docker image!"
                        echo "Files were not copied correctly during build."
                        exit 1
                    }
                    echo "✓ index.php found in image"

                    # Check other critical files
                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} test -f /var/www/html/db.php || {
                        echo "❌ ERROR: db.php not found in image"
                        exit 1
                    }
                    echo "✓ db.php found in image"

                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} test -f /var/www/html/.htaccess || {
                        echo "❌ ERROR: .htaccess not found in image"
                        exit 1
                    }
                    echo "✓ .htaccess found in image"

                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} test -d /var/www/html/api || {
                        echo "❌ ERROR: api directory not found in image"
                        exit 1
                    }
                    echo "✓ api directory found in image"

                    # List all files for verification
                    echo ""
                    echo "=== Files in Docker image ==="
                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} ls -la /var/www/html/
                    echo "=== End of file listing ==="

                    # Verify Apache configuration
                    echo ""
                    echo "Verifying Apache configuration..."
                    docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} apache2ctl configtest || {
                        echo "❌ ERROR: Apache configuration test failed"
                        exit 1
                    }
                    echo "✓ Apache configuration valid"

                    echo ""
                    echo "✓ Build verification passed!"
                '''
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh '''
                    docker-compose down
                    # Start test containers with specific project name
                    docker-compose -p n8n-web-app -f docker-compose.yml up -d db

                    # Wait for database to be ready
                    echo "Waiting for database to be ready..."
                    sleep 20

                    # Get the actual network name created by docker-compose
                    NETWORK_NAME=$(docker network ls --filter name=n8n-web-app --format "{{.Name}}" | grep n8n-network)

                    if [ -z "$NETWORK_NAME" ]; then
                        echo "Network not found, using default"
                        NETWORK_NAME="n8n-web-app_n8n-network"
                    fi

                    echo "Using network: $NETWORK_NAME"

                    # Test PHP version
                    docker run --rm \
                        --network $NETWORK_NAME \
                        -e DB_HOST=db \
                        -e DB_NAME=n8n_orders \
                        -e DB_USER=n8n_user \
                        -e DB_PASS=n8n_password \
                        ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        php -v

                    # Test database connection
                    docker run --rm \
                        --network $NETWORK_NAME \
                        -e DB_HOST=db \
                        -e DB_NAME=n8n_orders \
                        -e DB_USER=n8n_user \
                        -e DB_PASS=n8n_password \
                        ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        php -r "new PDO('mysql:host=db;dbname=n8n_orders', 'n8n_user', 'n8n_password'); echo 'Database connection successful';"

                    echo "Basic tests passed"
                '''
            }
            post {
                always {
                    sh 'docker-compose -p n8n-web-app -f docker-compose.yml down || true'
                }
            }
        }

        stage('Security Scan') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Running security scan...'
                script {
                    try {
                        // Using Trivy for vulnerability scanning
                        sh '''
                            if command -v trivy &> /dev/null; then
                                trivy image --severity HIGH,CRITICAL ${DOCKER_IMAGE}:${DOCKER_TAG}
                            else
                                echo "Trivy not installed, skipping security scan"
                            fi
                        '''
                    } catch (Exception e) {
                        echo "Security scan failed: ${e.getMessage()}"
                        // Don't fail the build, just warn
                    }
                }
            }
        }

        stage('Save Docker Image') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Saving Docker image to tar file...'
                sh '''
                    # Save Docker image to tar file
                    docker save ${DOCKER_IMAGE}:${DOCKER_TAG} -o ${DOCKER_IMAGE}-${DOCKER_TAG}.tar
                    docker save ${DOCKER_IMAGE}:latest -o ${DOCKER_IMAGE}-latest.tar

                    # Compress the image
                    gzip -f ${DOCKER_IMAGE}-${DOCKER_TAG}.tar
                    gzip -f ${DOCKER_IMAGE}-latest.tar

                    echo "Docker image saved to ${DOCKER_IMAGE}-${DOCKER_TAG}.tar.gz"
                '''
            }
        }

        stage('Transfer to Deployment Server') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Transferring files to deployment server...'
                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        # Create deployment directory on server
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "mkdir -p ${DEPLOY_PATH}"

                        # Transfer Docker image
                        scp -o StrictHostKeyChecking=no ${DOCKER_IMAGE}-${DOCKER_TAG}.tar.gz ${DEPLOY_SERVER}:${DEPLOY_PATH}/
                        scp -o StrictHostKeyChecking=no ${DOCKER_IMAGE}-latest.tar.gz ${DEPLOY_SERVER}:${DEPLOY_PATH}/

                        # Transfer application files
                        scp -o StrictHostKeyChecking=no -r htdocs/ ${DEPLOY_SERVER}:${DEPLOY_PATH}/
                        scp -o StrictHostKeyChecking=no docker-compose.yml ${DEPLOY_SERVER}:${DEPLOY_PATH}/
                        scp -o StrictHostKeyChecking=no .env.example ${DEPLOY_SERVER}:${DEPLOY_PATH}/
                        scp -o StrictHostKeyChecking=no if0_40626529_n8n.sql ${DEPLOY_SERVER}:${DEPLOY_PATH}/ || true

                        echo "Files transferred successfully"
                    '''
                }
            }
        }

        stage('Load Docker Image on Server') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Loading Docker image on deployment server...'
                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

                            # Decompress and load Docker image
                            gunzip -f ${DOCKER_IMAGE}-${DOCKER_TAG}.tar.gz
                            gunzip -f ${DOCKER_IMAGE}-latest.tar.gz

                            docker load -i ${DOCKER_IMAGE}-${DOCKER_TAG}.tar
                            docker load -i ${DOCKER_IMAGE}-latest.tar

                            # Clean up tar files
                            rm -f ${DOCKER_IMAGE}-${DOCKER_TAG}.tar
                            rm -f ${DOCKER_IMAGE}-latest.tar

                            echo "Docker image loaded successfully"
ENDSSH
                    '''
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                expression { env.IS_MASTER == 'false' }
            }
            steps {
                echo 'Deploying to staging environment...'
                sh '''
                    # Deploy to staging
                    docker-compose -f docker-compose.yml down || true
                    docker-compose -f docker-compose.yml up -d

                    # Wait for services to be healthy
                    sleep 10

                    # Verify deployment
                  #  curl -f http://localhost:8282 || { echo "Staging deployment failed"; exit 1; }
                '''
            }
        }

        stage('Deploy to Production') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Deploying to production environment...'
                input message: 'Deploy to production?', ok: 'Deploy'

                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

                            echo "=== Pre-deployment verification ==="

                            # Verify htdocs directory and files were transferred
                            echo "Checking transferred files..."
                            [ -d htdocs ] || { echo "ERROR: htdocs directory not found"; exit 1; }
                            [ -f htdocs/index.php ] || { echo "ERROR: htdocs/index.php not found"; exit 1; }
                            echo "✓ Application files present"

                            # Create .env if it doesn't exist
                            if [ ! -f .env ]; then
                                echo "Creating .env from .env.example"
                                cp .env.example .env
                                echo "IMPORTANT: Please configure .env with production values"
                            fi

                            # Backup current deployment
                            echo "Creating backup..."
                            if [ -d "backup" ]; then
                                rm -rf backup_old
                                mv backup backup_old
                            fi
                            mkdir -p backup
                            docker-compose ps -q | xargs -r docker inspect > backup/containers.json || true

                            # Remove old images to force using new ones
                            echo "Removing old images..."
                            docker-compose down || true
                            docker rmi n8n-web-app:latest 2>/dev/null || true

                            # Deploy new version
                            echo "Starting containers..."
                            docker-compose up -d

                            # Wait for services to be healthy
                            echo "Waiting for services to start..."
                            sleep 20

                            # Verify files in running container
                            echo ""
                            echo "=== Verifying files in container ==="
                            docker-compose exec web ls -la /var/www/html/

                            # Check if index.php exists in container
                            docker-compose exec web test -f /var/www/html/index.php || {
                                echo "❌ CRITICAL: index.php not found in container!"
                                echo "Deployment failed - rolling back..."
                                docker-compose down
                                exit 1
                            }
                            echo "✓ index.php found in container"

                            # Verify deployment
                            DEPLOY_PORT=\$(grep WEB_PORT .env | cut -d '=' -f2)
                            DEPLOY_PORT=\${DEPLOY_PORT:-8282}

                            echo ""
                            echo "Testing application on port \${DEPLOY_PORT}..."

                            # Try multiple times with delay
                            SUCCESS=0
                            for i in {1..5}; do
                                if curl -f http://localhost:\${DEPLOY_PORT} > /dev/null 2>&1; then
                                    SUCCESS=1
                                    break
                                fi
                                echo "Attempt \$i failed, retrying..."
                                sleep 3
                            done

                            if [ \$SUCCESS -eq 0 ]; then
                                echo "❌ Production deployment failed - application not accessible"
                                echo "Checking container logs:"
                                docker-compose logs --tail=50 web
                                echo ""
                                echo "Rolling back..."
                                docker-compose down
                                exit 1
                            fi

                            echo "✓ Application accessible"

                            # Cleanup old images
                            docker image prune -f

                            echo ""
                            echo "✅ Deployment successful!"
ENDSSH
                    '''
                }
            }
        }

        stage('Database Migration') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Running database migrations on deployment server...'
                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

                            # Check if migrations are needed
                            if [ -f "migrations.sql" ]; then
                                echo "Running migrations..."
                                docker-compose exec -T db mysql -u root -p\${MYSQL_ROOT_PASSWORD} \${DB_NAME} < migrations.sql
                            else
                                echo "No migrations to run"
                            fi
ENDSSH
                    '''
                }
            }
        }

        stage('Health Check') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Performing health checks on deployment server...'
                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

                            # Get deployment port
                            DEPLOY_PORT=\$(grep WEB_PORT .env | cut -d '=' -f2)
                            DEPLOY_PORT=\${DEPLOY_PORT:-8282}

                            # Check web service
                            for i in {1..5}; do
                                if curl -f http://localhost:\${DEPLOY_PORT}; then
                                    echo "Health check passed"
                                    exit 0
                                fi
                                echo "Attempt \$i failed, retrying..."
                                sleep 5
                            done
                            echo "Health check failed"
                            exit 1
ENDSSH
                    '''
                }
            }
        }

        stage('Smoke Tests') {
            when {
                expression { env.IS_MASTER == 'true' }
            }
            steps {
                echo 'Running smoke tests on deployment server...'
                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

                            # Get deployment port
                            DEPLOY_PORT=\$(grep WEB_PORT .env | cut -d '=' -f2)
                            DEPLOY_PORT=\${DEPLOY_PORT:-8282}

                            # Test main page
                            curl -f http://localhost:\${DEPLOY_PORT}/ || { echo "Main page test failed"; exit 1; }

                            # Test API endpoints
                            curl -f http://localhost:\${DEPLOY_PORT}/api/get_orders.php || { echo "API test failed"; exit 1; }

                            echo "Smoke tests passed"
ENDSSH
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            // Optional: Send notification
            // slackSend(channel: env.SLACK_CHANNEL, color: 'good',
            //     message: "Deployment successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }

        failure {
            echo 'Pipeline failed!'
            // Optional: Send notification
            // slackSend(channel: env.SLACK_CHANNEL, color: 'danger',
            //     message: "Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}")

            // Rollback on failure
            sh '''
                echo "Rolling back deployment..."
                docker-compose -f docker-compose.yml down || true
            '''
        }

        always {
            echo 'Cleaning up...'
            sh '''
                # Clean up Docker image tar files
                rm -f ${DOCKER_IMAGE}-*.tar.gz || true

                # Clean up dangling images
                docker image prune -f || true
            '''

            // Archive logs
            archiveArtifacts artifacts: '*.log', allowEmptyArchive: true

            // Clean workspace
            cleanWs()
        }
    }
}
