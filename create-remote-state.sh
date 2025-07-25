#!/bin/bash

# set variable for bucket-name
BUCKET_NAME="ecommerce-remote-state"
AWS_REGION="eu-west-1"
AWS_PROFILE="pmo-admin"

# create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# enable versioning
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --versioning-configuration Status=Enabled

echo "Creating Jenkins Server"
cd jenkins
terraform init 
terraform validate
terraform apply -auto-approve