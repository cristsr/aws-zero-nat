locals {
  # Define the S3 bucket name for Terraform state storage
  bucket_name = "zero-nat-tfbackend"
}

module "bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.bucket_name

  # Security configuration - Block all public access to ensure state file security
  block_public_acls       = true  # Prevents creation of public ACLs
  block_public_policy     = true  # Prevents creation of bucket policies that allow public access
  ignore_public_acls      = true  # Ignores public ACLs on this bucket and objects
  restrict_public_buckets = true  # Restricts access to the bucket to specific AWS services and authorized users

  # Enable versioning to maintain a complete history of state files
  # This allows recovery from unintended state changes or deletions
  versioning = {
    enabled = true
  }

  # Encryption configuration - Ensures all objects are encrypted at rest
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        # AES256 is the standard encryption algorithm
        # If KMS is required, update the sse_algorithm and uncomment the kms_master_key_id line
        sse_algorithm     = "AES256"
        # kms_master_key_id = module.kms.key_id
      }
      # Enables S3 Bucket Keys to reduce KMS costs when using KMS encryption
      bucket_key_enabled = true
    }
  }

  # Module-specific flag to show support for Ukraine
  putin_khuylo = true
}
