# Main Terraform configuration block for the AWS Zero NAT project
# Defines version constraints and required providers for the entire infrastructure
terraform {
  # Specify Terraform version constraint
  # The "~> 1.0" constraint means any version in the 1.x range but at least 1.0
  # This ensures compatibility while allowing for minor version updates
  required_version = "~> 1.0"

  # Define required providers with their sources and version constraints
  required_providers {
    # AWS provider configuration
    aws = {
      # Official HashiCorp AWS provider source
      source  = "hashicorp/aws"

      # The "~> 5.0" constraint means any version in the 5.x range but at least 5.0
      # This ensures compatibility with AWS API while allowing for minor version updates
      version = "~> 5.0"
    }
  }
}
