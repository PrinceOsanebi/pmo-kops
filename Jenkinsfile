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
          // sh 'pip install pipenv'
          // sh 'pip install checkov'
          sh 'python -m venv venv'
          sh 'source venv/bin/activate'
          sh 'pip install -U pip'
          // sh 'pip install --ignore-installed checkov==3.2.438'
          sh 'pip install --ignore-installed checkov'
          def checkovStatus = sh(script: "checkov -d . -o cli -o junitxml --output-file-path console,results.xml --quiet --compact", returnStatus: true)
          junit skipPublishingChecks: true, testResults: 'results.xml'
          echo "Checkov command exited with status ${checkovStatus}"
          // Optional: fail build if issues found
          // if (checkovStatus != 0) {
          //   error "Checkov found vulnerabilities or errors."
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
  }
}
