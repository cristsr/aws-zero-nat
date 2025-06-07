module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = var.domain
  zone_id     = aws_route53_zone.main.id

  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain}",
    "www.${var.domain}",
  ]

  wait_for_validation = true

  tags = {
    Name      = var.domain
    Terraform = "true"
  }
}
