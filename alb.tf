locals {
  region   = var.region
  alb_name = "zero-nat-alb"

  alb_tags = {
    Name      = local.alb_name
    Terraform = "true"
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = local.alb_name
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # For example only
  enable_deletion_protection = false

  security_groups = []
  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 82
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 445
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  # client_keep_alive = 7200

  # Listeners simplificados
  listeners = {
    # HTTP → HTTPS redirect
    http = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # HTTPS con fixed response
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      certificate_arn = module.acm.acm_certificate_arn

      # Default action: responder texto plano
      fixed_response  = {
        content_type = "text/plain"
        message_body = "Hello from ALB! This is a secure HTTPS response."
        status_code  = "200"
      }
    }
  }

  # Route53 Record
  route53_records = {
    A = {
      name    = ""
      type    = "A"
      zone_id = aws_route53_zone.main.id
    }
  }

  tags = local.alb_tags
}
