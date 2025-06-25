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
    CHECKOV_REPORT = 'checkov_console_output.txt'
    CHECKOV_XML = 'checkov_results.xml'
    HTML_REPORT_DIR = 'checkov_html_report'
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Checkov IaC Security Scan') {
      steps {
        script {
          sh '''
            rm -rf venv ${HTML_REPORT_DIR}
            python3 -m venv venv
            . venv/bin/activate
            pip install --upgrade pip
            pip install --quiet checkov

            checkov -d . -o cli -o junitxml \
              --output-file-path ${CHECKOV_REPORT},${CHECKOV_XML} \
              --quiet --compact || true

            # Create HTML report with a basic bar-style summary
            mkdir -p ${HTML_REPORT_DIR}
            echo "<html><head><title>Checkov Report</title></head><body>" > ${HTML_REPORT_DIR}/index.html
            echo "<h2>Checkov Summary</h2>" >> ${HTML_REPORT_DIR}/index.html
            echo "<pre>" >> ${HTML_REPORT_DIR}/index.html
            cat ${CHECKOV_REPORT} >> ${HTML_REPORT_DIR}/index.html
            echo "</pre>" >> ${HTML_REPORT_DIR}/index.html
            echo "</body></html>" >> ${HTML_REPORT_DIR}/index.html
          '''

          junit skipPublishingChecks: true, testResults: "${env.CHECKOV_XML}"
          archiveArtifacts artifacts: "${env.CHECKOV_REPORT},${env.CHECKOV_XML}", allowEmptyArchive: true
        }
      }
    }

    stage('Publish HTML Report') {
      steps {
        publishHTML([
          reportDir: "${env.HTML_REPORT_DIR}",
          reportFiles: 'index.html',
          reportName: 'Checkov IaC Security Report',
          allowMissing: false,
          alwaysLinkToLastBuild: true,
          keepAll: true
        ])
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

  post {
    success {
      echo "✅ Build succeeded."
    }
    failure {
      echo "❌ Build failed."
    }
    unstable {
      echo "⚠️ Build marked unstable."
    }
    always {
      echo "📦 Pipeline complete. Reports archived and HTML published."
    }
  }
}
