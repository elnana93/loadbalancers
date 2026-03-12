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
If you want a version that helps you debug fast, use this one: Use this later
 */
/* 

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
                sh '''
                    echo "=== AWS caller identity before init ==="
                    aws sts get-caller-identity
                    terraform init
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh '''
                    echo "=== AWS caller identity before plan ==="
                    aws sts get-caller-identity
                    terraform plan -out=tfplan
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                    echo "=== AWS caller identity before apply ==="
                    aws sts get-caller-identity
                    terraform apply -auto-approve tfplan
                '''
            }
        }
    }
}
_________________________________________________________________________
 */
/*
/use this stage to destroy the infrastructure when needed

 stage('Terraform Destroy') {
    steps {
        sh 'terraform destroy -auto-approve'
    }

} 
*/