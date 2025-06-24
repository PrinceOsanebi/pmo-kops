# create aws provider
provider "aws" {
  region  = "eu-west-1"
 }

terraform {
  backend "s3" {
    bucket       = "ecommerce-remote-state"
    use_lockfile = true
    key          = "kops/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    }
}