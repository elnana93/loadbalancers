pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

     stage('Terraform Init') {
        steps {
            sh 'terraform init -reconfigure'
            }
}

        stage('Terraform Plan') {
            steps {
                sh '''
                    aws sts get-caller-identity
                    terraform plan -out=tfplan
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                    terraform apply -auto-approve tfplan
                '''
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
*/