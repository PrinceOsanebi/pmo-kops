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
            source venv/bin/activate
            pip install --upgrade pip==23.2.2
            pip install pipenv==2023.4.29
            pip install checkov==3.2.438
          '''

          def checkovStatus = sh(script: '''
            source venv/bin/activate
            checkov -d . --download-external-modules -o cli -o junitxml \
              --output-file-path checkov_output.txt,results.xml --quiet --compact
          ''', returnStatus: true)

          junit skipPublishingChecks: true, testResults: 'results.xml'
          archiveArtifacts artifacts: 'checkov_output.txt'

          echo "Checkov command exited with status ${checkovStatus}"

          // Uncomment to fail build if Checkov finds issues
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
