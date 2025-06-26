pipeline {
  agent any
  tools {
    terraform 'terraform'
  }

  parameters {
    choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
  }

  stages {
    stage('Checkov - IAC Scan') {
      steps {
        script {
          // Setup Python environment and install Checkov
          sh 'python3 -m venv venv'
          sh '. venv/bin/activate && pip install -U pip && pip install --ignore-installed checkov'

          // Run Checkov scan with CLI and JUnitXML outputs
          def checkovStatus = sh(
            script: ". venv/bin/activate && checkov -d . -o cli -o junitxml --output-file-path console,results.xml --quiet --compact",
            returnStatus: true
          )

          // Text output of the scan
          echo "=== Checkov CLI Output ==="
          sh 'cat console'

          // Publish test results graphically (JUnit plugin in Jenkins)
          junit skipPublishingChecks: true, testResults: 'results.xml'

          // Archive console output so it's downloadable
          archiveArtifacts artifacts: 'console', onlyIfSuccessful: false

          echo "Checkov exited with status ${checkovStatus}"
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
  }
}
