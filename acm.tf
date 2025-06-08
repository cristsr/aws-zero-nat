# AWS Certificate Manager (ACM) Configuration
# Creates an SSL/TLS certificate for secure HTTPS connections
# This certificate will be used by the Application Load Balancer
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"  # Using version 4.x of the ACM module

  # Primary domain name for the certificate
  domain_name = var.domain_name

  # Reference to the Route 53 hosted zone for DNS validation
  # This links the certificate to the DNS configuration
  zone_id     = aws_route53_zone.main.id

  # DNS validation is more reliable than email validation
  # and allows for automatic renewal of certificates
  validation_method = "DNS"

  # Additional domain names covered by this certificate
  subject_alternative_names = [
    "*.${var.domain_name}",  # Wildcard certificate covers all subdomains
    "www.${var.domain_name}",  # Explicitly include www subdomain for compatibility
  ]

  # Wait for certificate validation to complete before considering
  # the Terraform apply complete - ensures certificate is ready for use
  wait_for_validation = true

  # Tags for resource identification and management
  tags = {
    Name        = "${var.domain_name} SSL Certificate"
    ManagedBy   = "terraform"
    Purpose     = "HTTPS encryption for web traffic"
    Environment = "production"
  }
}
