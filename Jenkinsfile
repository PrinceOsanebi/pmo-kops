pipeline {
  agent any

  tools {
    terraform 'terraform' // Ensure this matches name under "Manage Jenkins" > "Global Tool Configuration"
  }

  parameters {
    choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
  }

  triggers {
    cron('* * * * *') // Run every minute
  }

  environment {
    CHECKOV_VERSION = '3.2.438'
    CHECKOV_REPORT = 'checkov_report.txt'
    CHECKOV_XML = 'checkov_results.xml'
    SLACK_CHANNEL = 'Prince, OSANEBI Maluabuchukwu'
    SLACK_CREDENTIAL_ID = 'ctXYtFKc4wtCtzXTmddolWhL'
  }

  options {
    ansiColor('xterm')
    timestamps()
  }

  stages {
    stage('Prepare Python Environment') {
      steps {
        sh '''
          python3 -m venv venv
          . venv/bin/activate
          pip install --upgrade pip
          pip install checkov==${CHECKOV_VERSION}
        '''
      }
    }

    stage('Checkov Scan (IaC Security)') {
      steps {
        script {
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

          // Optional failure on issues
          // if (checkovStatus != 0) {
          //   error "Checkov reported issues."
          // }
        }
      }
    }

    stage('Terraform Init') {
      steps {
        sh 'terraform init'
      }
    }

    stage('Terraform Format') {
      steps {
        sh 'terraform fmt --recursive'
      }
    }

    stage('Terraform Validate') {
      steps {
        sh 'terraform validate'
      }
    }

    stage('Terraform Plan') {
      steps {
        sh 'terraform plan'
      }
    }

    stage('Terraform Action') {
      steps {
        sh "terraform ${params.action} -auto-approve"
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
