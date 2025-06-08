# AWS Provider Configuration for the main AWS Zero NAT infrastructure
provider "aws" {
  # Use the region defined in variables
  # This allows for environment-specific configuration
  region = var.region
}

# Retrieve information about available AWS availability zones in the current region
# This ensures the infrastructure is deployed only in operational AZs
data "aws_availability_zones" "available" {
  # Filter to include only AZs in the "available" state
  # This excludes AZs that might be impaired or otherwise unavailable
  state = "available"
}
