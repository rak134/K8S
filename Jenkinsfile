pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'  // Change as needed
        ECR_REGISTRY = '<your-account-id>.dkr.ecr.${AWS_REGION}.amazonaws.com'
        IMAGE_NAME = "${ECR_REGISTRY}/demo-project"
        K8S_CLUSTER = 'demo-cluster'  // Your EKS cluster name
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/your-repo/demo-project.git'
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:${env.BUILD_NUMBER}")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    dockerImage.push()
                    dockerImage.push('latest')
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${K8S_CLUSTER}"
                    sh "kubectl apply -f deployment.yml"
                    sh "kubectl rollout status deployment/demo-deployment"
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Deployment completed successfully!'
        }
        failure {
            echo 'Deployment failed!'
        }
    }
}