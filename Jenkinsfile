pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/elnana93/LoadBalancers.git'
            }
        }

        stage('Who am I') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
    }
}



/*
/use this stage to destroy the infrastructure when needed

 stage('Terraform Destroy') {
    steps {
        sh 'terraform destroy -auto-approve'
    }

} 



stage('Terraform Apply') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }



*/