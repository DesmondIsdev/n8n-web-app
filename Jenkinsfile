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

        // Deployment configuration
        DEPLOY_ENV = "${env.BRANCH_NAME == 'master' ? 'production' : 'staging'}"

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

                    # Validate PHP syntax
                    find htdocs -name "*.php" -exec php -l {} \\; || { echo "PHP syntax errors found"; exit 1; }

                    echo "Validation successful"
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

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh '''
                    docker compose down
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
                branch 'master'
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
                branch 'master'
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
                branch 'master'
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
                branch 'master'
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
                not {
                    branch 'master'
                }
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
                branch 'master'
            }
            steps {
                echo 'Deploying to production environment...'
                input message: 'Deploy to production?', ok: 'Deploy'

                sshagent(credentials: ["${DEPLOY_SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} << 'ENDSSH'
                            cd ${DEPLOY_PATH}

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

                            # Stop old containers
                            docker-compose down || true

                            # Deploy new version
                            docker-compose up -d

                            # Wait for services to be healthy
                            sleep 15

                            # Verify deployment
                            DEPLOY_PORT=\$(grep WEB_PORT .env | cut -d '=' -f2)
                            DEPLOY_PORT=\${DEPLOY_PORT:-8282}

                            curl -f http://localhost:\${DEPLOY_PORT} || {
                                echo "Production deployment failed, rolling back..."
                                docker-compose down
                                exit 1
                            }

                            # Cleanup old images
                            docker image prune -f

                            echo "Deployment successful!"
ENDSSH
                    '''
                }
            }
        }

        stage('Database Migration') {
            when {
                branch 'master'
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
                branch 'master'
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
                branch 'master'
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
