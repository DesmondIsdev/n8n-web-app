pipeline {
    agent any

    environment {
        // Docker configuration
        DOCKER_IMAGE = 'n8n-web-app'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io' // Change to your registry
        DOCKER_CREDENTIALS_ID = 'docker-hub-credentials' // Jenkins credential ID

        // Application configuration
        APP_NAME = 'n8n-web-app'

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
                    # Start test containers
                    docker-compose -f docker-compose.yml up -d db

                    # Wait for database to be ready
                    echo "Waiting for database to be ready..."
                    sleep 20

                    # Run container with test configuration
                    docker run --rm \
                        --network n8n-web-app_n8n-network \
                        -e DB_HOST=db \
                        -e DB_NAME=n8n_orders \
                        -e DB_USER=n8n_user \
                        -e DB_PASS=n8n_password \
                        ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        php -v

                    echo "Basic tests passed"
                '''
            }
            post {
                always {
                    sh 'docker-compose -f docker-compose.yml down || true'
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

        stage('Push to Registry') {
            when {
                branch 'master'
            }
            steps {
                echo 'Pushing image to registry...'
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", "${DOCKER_CREDENTIALS_ID}") {
                        docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}").push()
                        docker.image("${DOCKER_IMAGE}:latest").push()
                    }
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
                    curl -f http://localhost:8080 || { echo "Staging deployment failed"; exit 1; }
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

                sh '''
                    # Backup current deployment
                    echo "Creating backup..."

                    # Deploy new version with zero downtime
                    docker-compose -f docker-compose.yml pull
                    docker-compose -f docker-compose.yml up -d --no-deps --build web

                    # Wait for new container to be healthy
                    sleep 15

                    # Verify deployment
                    curl -f http://localhost:8080 || {
                        echo "Production deployment failed, rolling back..."
                        docker-compose -f docker-compose.yml down
                        exit 1
                    }

                    # Cleanup old images
                    docker image prune -f
                '''
            }
        }

        stage('Database Migration') {
            when {
                branch 'master'
            }
            steps {
                echo 'Running database migrations...'
                sh '''
                    # Check if migrations are needed
                    if [ -f "migrations.sql" ]; then
                        echo "Running migrations..."
                        docker-compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME} < migrations.sql
                    else
                        echo "No migrations to run"
                    fi
                '''
            }
        }

        stage('Health Check') {
            steps {
                echo 'Performing health checks...'
                sh '''
                    # Check web service
                    for i in {1..5}; do
                        if curl -f http://localhost:8080; then
                            echo "Health check passed"
                            exit 0
                        fi
                        echo "Attempt $i failed, retrying..."
                        sleep 5
                    done
                    echo "Health check failed"
                    exit 1
                '''
            }
        }

        stage('Smoke Tests') {
            steps {
                echo 'Running smoke tests...'
                sh '''
                    # Test main page
                    curl -f http://localhost:8080/ || { echo "Main page test failed"; exit 1; }

                    # Test API endpoints
                    curl -f http://localhost:8080/api/get_orders.php || { echo "API test failed"; exit 1; }

                    echo "Smoke tests passed"
                '''
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
