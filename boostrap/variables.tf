# AWS Region Variable
# Defines the AWS region where resources will be created
variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"  # North Virginia region, AWS's primary region with all services available
}
