locals {
  user_data = <<-EOF
#!/bin/bash  
sudo apt update -y
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops
sudo mv kops /usr/local/bin/kops 

#updating server and installing dependencies
sudo apt-get update -y
sudo apt-get install -y wget curl unzip git

#installing aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

#installing kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv ./kubectl /usr/local/bin/kubectl

#installing argocd
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

#installing kops
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops
sudo mv kops /usr/local/bin/kops

#installing Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

#exporting variable for route 53 and s3 bucket
export NAME=pmolabs.space
export KOPS_STATE_STORE=s3://ecommerce-remote-state

# creating keypair
sudo su -c "ssh-keygen -t rsa -m pem -q -N '' -f /home/ubuntu/.ssh/id_rsa" ubuntu

# creating kubernetes cluster
sudo su -c "kops create cluster --cloud=aws \
  --node-count=4 \
  --node-size=t2.medium \
  --master-size=t2.medium \
  --control-plane-zones=eu-west-1a,eu-west-1b,eu-west-1c \
  --zones=eu-west-1a,eu-west-1b,eu-west-1c \
  --ssh-public-key=/home/ubuntu/.ssh/id_rsa.pub \
  --topology=private \
  --bastion \
  --networking=calico \
  --state=$KOPS_STATE_STORE \
  --name=$NAME \
  --yes" ubuntu

# updating cluster
sudo su -c "kops update cluster --name=$NAME --state=$KOPS_STATE_STORE --yes --admin" ubuntu

# watch cluster creation
sudo su -c "kops validate cluster --name=$NAME --state=$KOPS_STATE_STORE --wait 10m" ubuntu
EOF
}