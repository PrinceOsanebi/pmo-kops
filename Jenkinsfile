pipeline {
  agent any

  tools {
    terraform 'terraform'
  }

  parameters {
    choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
  }

  triggers {
    cron('* * * * *')
  }

  environment {
    CHECKOV_VERSION = '3.2.438'
    CHECKOV_REPORT = 'checkov_report.txt'
    CHECKOV_XML = 'checkov_results.xml'
    SLACK_CHANNEL = 'Prince, OSANEBI Maluabuchukwu'
    SLACK_CREDENTIAL_ID = 'ctXYtFKc4wtCtzXTmddolWhL'
  }

  options {
    timestamps()
  }

  stages {
    stage('Prepare Python Environment') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh '''
              python3 -m venv venv
              . venv/bin/activate
              pip install --upgrade pip
              pip install checkov==${CHECKOV_VERSION}
            '''
          }
        }
      }
    }

    stage('Checkov Scan (IaC Security)') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            def checkovCmd = """
              . venv/bin/activate
              checkov -d . \\
                -o cli \\
                -o junitxml \\
                --output-file-path ${env.CHECKOV_REPORT},${env.CHECKOV_XML} \\
                --quiet --compact
            """
            def checkovStatus = sh(script: checkovCmd, returnStatus: true)

            echo "Checkov exited with status: ${checkovStatus}"
            junit skipPublishingChecks: true, testResults: "${env.CHECKOV_XML}"
          }
        }
      }
    }

    stage('Terraform Init') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh 'terraform init'
          }
        }
      }
    }

    stage('Terraform Format') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh 'terraform fmt --recursive'
          }
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh 'terraform validate'
          }
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh 'terraform plan'
          }
        }
      }
    }

    stage('Terraform Action') {
      steps {
        script {
          wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
            sh "terraform ${params.action} -auto-approve"
          }
        }
      }
    }

    stage('Archive Reports') {
      steps {
        archiveArtifacts artifacts: "${env.CHECKOV_REPORT},${env.CHECKOV_XML}", allowEmptyArchive: true
      }
    }
  }

  post {
    success {
      slackSend(
        channel: "${env.SLACK_CHANNEL}",
        color: 'good',
        message: "*SUCCESS*: Jenkins job `${env.JOB_NAME}` #${env.BUILD_NUMBER} completed successfully. <${env.BUILD_URL}|View Job>"
      )
    }
    failure {
      slackSend(
        channel: "${env.SLACK_CHANNEL}",
        color: 'danger',
        message: "*FAILURE*: Jenkins job `${env.JOB_NAME}` #${env.BUILD_NUMBER} failed. <${env.BUILD_URL}|View Job>"
      )
    }
    always {
      echo "Build completed. Artifacts archived, notifications sent."
    }
  }
}
