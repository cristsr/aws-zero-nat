# AWS Region Variable
# Defines the AWS region where all resources will be created
variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"  # North Virginia region, AWS's primary region with all services available
}

# Domain Name Variable
# Defines the domain name to be used for DNS and certificate configuration
variable "domain_name" {
  description = "The domain name to use for the application"
  type        = string
  default     = "cristianpuenguenan.online"  # Default domain for this project
  # This domain should be registered and managed in Route53 for proper DNS configuration
}
