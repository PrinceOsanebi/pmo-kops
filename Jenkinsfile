pipeline {
    agent any
    tools {
        terraform 'terraform'
    }
    parameters {
        choice(name: 'action', choices: ['apply', 'destroy'], description: 'Select the action to perform')
    }
    triggers {
        pollSCM('* * * * *') // Runs every minuite
    }
    environment {
        SLACKCHANNEL = 'Prince, OSANEBI Maluabuchukwu' //MY CHANNEL ID
        SLACKCREDENTIALS = credentials('slack')
    }
    
    stages {
        stage('IAC Scan') {
            steps {
                script {
                    sh 'pip install checkov'
                    sh 'checkov -d . -o junitxml > checkov-report.xml'
                    sh 'checkov -d . -o html > checkov-report.html'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'checkov-report.xml'
                    archiveArtifacts artifacts: 'checkov-report.html', fingerprint: true
                }
            }
        }
        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }
        stage('Terraform format') {
            steps {
                sh 'terraform fmt --recursive'
            }
        }
        stage('Terraform validate') {
            steps {
                sh 'terraform validate'
            }
        }
        stage('Terraform plan') {
            steps {
                sh 'terraform plan'
            }
        }
        stage('Terraform action') {
            steps {
                script {
                    sh "terraform ${action} -auto-approve"
                }
            }
        }
    }
    post {
        always {
            script {
                slackSend(
                    channel: SLACKCHANNEL,
                    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
                    message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) has been completed."
                )
            }
        }
        failure {
            slackSend(
                channel: SLACKCHANNEL,
                color: 'danger',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has failed. Check console output at ${env.BUILD_URL}."
            )
        }
        success {
            slackSend(
                channel: SLACKCHANNEL,
                color: 'good',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' completed successfully. Check console output at ${env.BUILD_URL}."
            )
        }
    }
}
