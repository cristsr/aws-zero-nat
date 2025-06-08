# AWS Provider Configuration
# This block configures the AWS provider with the specified region
provider "aws" {
  # Use the region defined in variables
  # This allows for environment-specific configuration
  region = var.region
}

# Retrieve information about the AWS account currently in use
# This data source can be used to get the Account ID, User ID, and ARN
# Useful for creating resources that need account-specific information
data "aws_caller_identity" "current" {}
