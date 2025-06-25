pipeline {
  agent any
  tools {
    terraform 'terraform'
  }

  parameters {
    choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
  }

  stages {
    stage('Checkov') {
      steps {
        script {
          sh 'python -m venv venv'
          sh 'source venv/bin/activate && pip install -U pip'
          sh 'source venv/bin/activate && pip install --ignore-installed checkov'
          def checkovStatus = sh(script: '''
            source venv/bin/activate
            checkov -d . -o cli -o junitxml --output-file-path checkov_output.txt,checkov_results.xml --quiet --compact
          ''', returnStatus: true)
          junit skipPublishingChecks: true, testResults: 'checkov_results.xml'
          echo "Checkov command exited with status ${checkovStatus}"
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
