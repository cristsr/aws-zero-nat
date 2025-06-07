resource "aws_route53_zone" "main" {
  name = var.domain

  tags = {
    Terraform = "true"
  }
}

output "main_zone_id" {
  value = aws_route53_zone.main.id
}

output "nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "Configure these nameservers itn the domain provider"
}
