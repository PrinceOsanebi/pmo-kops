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
          sh '''
            python3 -m venv venv
            . venv/bin/activate
            pip install -U pip
            pip install checkov
            checkov -d . -o cli -o junitxml --output-file-path console,results.xml --quiet --compact
          '''
          junit skipPublishingChecks: true, testResults: 'results.xml'
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
        sh 'terraform plan -out=tfplan'
      }
    }

    stage('Terraform Action') {
      steps {
        sh "terraform ${params.action} -auto-approve tfplan"
      }
    }
  }
}
