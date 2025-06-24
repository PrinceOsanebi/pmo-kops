#!/bin/bash
# Update packages and install dependencies
sudo yum update -y
sudo yum install -y wget git pip maven yum-utils unzip curl

# Install Amazon SSM Agent
sudo dnf install -y "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm"

# Install AWS Session Manager Plugin
SESSION_MANAGER_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
curl -fsSL "$SESSION_MANAGER_PLUGIN_URL" -o session-manager-plugin.rpm
sudo yum install -y session-manager-plugin.rpm
rm -f session-manager-plugin.rpm

# Add Jenkins repository and import key
sudo wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade after repo addition
sudo yum upgrade -y

# Install Java 17 and Jenkins
sudo yum install -y java-17-openjdk jenkins

# Configure Jenkins service to run as root (if absolutely needed)
sudo sed -i 's/^User=jenkins/User=root/' /usr/lib/systemd/system/jenkins.service
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins

# Add ec2-user to Jenkins group
sudo usermod -aG jenkins ec2-user

# Install Trivy for container scanning
RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "7")
sudo tee /etc/yum.repos.d/trivy.repo > /dev/null <<EOF
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/${RELEASE_VERSION}/\$basearch/
gpgcheck=0
enabled=1
EOF
sudo yum update -y
sudo yum install -y trivy

# Install Docker CE
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
sudo systemctl enable --now docker

# Add users to Docker group for permission to manage docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins

# Secure Docker socket permissions (restrict to owner and group)
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

# Install AWS CLI v2
AWS_CLI_ZIP="awscliv2.zip"
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o $AWS_CLI_ZIP
unzip -o $AWS_CLI_ZIP
sudo ./aws/install --update
rm -rf aws $AWS_CLI_ZIP

# Create hostname
sudo hostnamectl set-hostname jenkins

echo "Setup completed successfully."
