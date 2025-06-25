pipeline {
  agent any

  tools {
    terraform 'terraform'
  }

  parameters {
    choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
  }

  triggers {
    cron('* * * * *') // Every minute
  }

  options {
    timestamps()
  }

  stages {
    stage('Checkov (IaC Security Scan)') {
      steps {
        script {
          sh '''
            python3 -m venv venv
            . venv/bin/activate
            pip install --upgrade pip
            pip install checkov
          '''
          def checkovStatus = sh(
            script: '''
              . venv/bin/activate
              checkov -d . \
                -o cli \
                -o junitxml \
                --output-file-path checkov_output.txt,checkov_results.xml \
                --quiet --compact
            ''',
            returnStatus: true
          )

          // Publish graphical results
          junit skipPublishingChecks: true, testResults: 'checkov_results.xml'

          // Archive text scan results
          archiveArtifacts artifacts: 'checkov_output.txt,checkov_results.xml', allowEmptyArchive: true

          // Mark build as unstable if Checkov found issues
          if (checkovStatus != 0) {
            currentBuild.result = 'UNSTABLE'
            echo "Checkov found policy violations — marking build as UNSTABLE"
          } else {
            echo "Checkov passed with no issues"
          }
        }
      }
    }

    stage('Terraform Init') {
      steps {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
          sh 'terraform init'
        }
      }
    }

    stage('Terraform Format') {
      steps {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
          sh 'terraform fmt --recursive'
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
          sh 'terraform validate'
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
          sh 'terraform plan'
        }
      }
    }

    stage('Terraform Apply/Destroy') {
      steps {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
          sh "terraform ${params.action} -auto-approve"
        }
      }
    }
  }

  post {
    success {
      echo "✅ Build succeeded."
    }
    unstable {
      echo "⚠️ Build completed but marked UNSTABLE due to IaC policy violations."
    }
    failure {
      echo "❌ Build failed."
    }
    always {
      echo "ℹ️ Build completed. Artifacts archived."
    }
  }
}
