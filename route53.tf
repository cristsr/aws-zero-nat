# Route 53 Hosted Zone Configuration
# Creates a public hosted zone for the domain specified in variables
# This hosted zone will manage DNS records for the application
resource "aws_route53_zone" "main" {
  # Use the domain name from variables.tf
  name = var.domain_name

  # Tags for resource identification and management
  tags = {
    ManagedBy = "terraform"
    Name      = "${var.domain_name} Hosted Zone"
    Purpose   = "DNS management for Zero-NAT infrastructure"
  }
}

# Output the Zone ID for reference and potential use in other modules
# This ID is needed when creating DNS records in this zone from other Terraform configurations
output "main_zone_id" {
  value       = aws_route53_zone.main.id
  description = "The Route 53 Hosted Zone ID for the domain"
}

# Output the nameservers assigned by AWS for this hosted zone
# These nameservers need to be configured at the domain registrar to delegate DNS to Route 53
output "nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "Configure these nameservers in the domain provider's DNS settings"
}
