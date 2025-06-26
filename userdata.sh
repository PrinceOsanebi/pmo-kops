locals {
  user_data = <<-EOF
#!/bin/bash
# Updating server and installing dependencies
sudo apt-get update -y
sudo apt-get install -y wget curl unzip git

# Installing AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Installing kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Installing Argo CD
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Installing kops
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops
sudo mv kops /usr/local/bin/kops

# Installing Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Exporting and echoing variables for Route 53 and S3 bucket
export NAME="pmolabs.space"
export KOPS_STATE_STORE="s3://kopsecommerce-remote-state"
echo "Domain Name: \$NAME"
echo "KOPS State Store Bucket: \$KOPS_STATE_STORE"

# Persisting these variables to bashrc
echo 'export NAME="pmolabs.space"' >> ~/.bashrc
echo 'export KOPS_STATE_STORE="s3://ecommerce-remote-state"' >> ~/.bashrc
EOF
}
