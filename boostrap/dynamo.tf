# DynamoDB table for Terraform state locking
# This prevents concurrent operations on the same state file which could cause conflicts
module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  # Table name that identifies its purpose for the AWS Zero NAT project
  name         = "AwsZeroNatTerraformLocks"

  # The hash key "LockID" is required by Terraform for state locking
  # Terraform will use this attribute to create and identify locks
  hash_key     = "LockID"

  # PAY_PER_REQUEST (on-demand) billing mode is cost-effective for state locking
  # since the table is only accessed during terraform operations
  billing_mode = "PAY_PER_REQUEST"

  # Define the LockID attribute as a string type
  # This is the only attribute needed for Terraform state locking
  attributes = [
    {
      name = "LockID"  # Attribute name used by Terraform
      type = "S"       # String data type
    }
  ]

  # Server-side encryption is disabled for this table with KMS
  # Consider enabling this for production environments with sensitive data
  server_side_encryption_enabled = false

  # Point-in-time recovery is disabled to reduce costs
  # Enable this if you need the ability to restore the table to a specific point in time
  point_in_time_recovery_enabled = false

  # Tags for resource identification, management, and cost allocation
  tags = {
    Name        = "AWS Zero NAT Terraform Locks"
    Purpose     = "Terraform state locking"
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "aws-zero-nat"
  }
}
