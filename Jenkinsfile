pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-east-1'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/rjeunecrack/jenkins.git'
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform/aws') {
                    sh 'terraform init'
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform/aws') {
                    sh 'terraform plan'
                }
            }
        }
        
        stage('Approve Deploy') {
            steps {
                input message: 'Déployer l\'infrastructure AWS ?', 
                      ok: 'Déployer',
                      submitterParameter: 'DEPLOYER'
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir('terraform/aws') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
