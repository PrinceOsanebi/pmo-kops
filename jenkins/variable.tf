variable "domain" {
  description = "The domain name the project"
  type        = string
  default     = "pmolabs.space"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}
