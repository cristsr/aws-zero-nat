# Local variables for Application Load Balancer configuration
locals {
  # AWS region from variables
  region   = var.region

  # Name for the Application Load Balancer
  alb_name = "zero-nat-alb"

  # Tags for ALB resource identification and management
  alb_tags = {
    Name        = local.alb_name
    ManagedBy   = "terraform"
    Purpose     = "Web traffic distribution"
    Environment = "production"
  }
}

# Application Load Balancer Module Configuration
# This ALB serves as the entry point for all web traffic to the application
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  # Use the name defined in locals
  name    = local.alb_name

  # Place the ALB in the VPC created earlier
  vpc_id  = module.vpc.vpc_id

  # Deploy the ALB in the public subnets for internet accessibility
  # This follows the Zero-NAT architecture pattern
  subnets = module.vpc.public_subnets

  # Disable deletion protection for easier cleanup in development/testing
  # For production, this should be set to true to prevent accidental deletion
  enable_deletion_protection = false

  # Security group configuration for the ALB
  security_groups = []

  # Ingress rules - control incoming traffic to the ALB
  security_group_ingress_rules = {
    # Allow HTTP traffic from anywhere (will be redirected to HTTPS)
    all_http = {
      from_port   = 80
      to_port     = 82  # Range allows for potential future port assignments
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"  # Open to the internet
    }
    # Allow HTTPS traffic from anywhere
    all_https = {
      from_port   = 443
      to_port     = 445  # Range allows for potential future port assignments
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"  # Open to the internet
    }
  }

  # Egress rules - control outgoing traffic from the ALB
  security_group_egress_rules = {
    # Allow all outbound traffic but only within the VPC
    # This is a security best practice to limit the scope of outbound traffic
    all = {
      ip_protocol = "-1"  # All protocols
      cidr_ipv4   = module.vpc.vpc_cidr_block  # Restrict to VPC CIDR
    }
  }

  # Uncomment to adjust client timeout settings if needed
  # client_keep_alive = 7200

  # Listener Configuration
  # Listeners define how the ALB processes incoming requests
  listeners = {
    # HTTP Listener - Redirects all HTTP traffic to HTTPS for security
    http = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"  # Permanent redirect
      }
    }

    # HTTPS Listener - Handles secure traffic with TLS
    https = {
      port            = 443
      protocol        = "HTTPS"
      # Modern TLS policy that supports TLS 1.3 and 1.2 with strong ciphers
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      # Use the certificate created by the ACM module
      certificate_arn = module.acm.acm_certificate_arn

      # Default action: Return a simple text response
      # In a real application, this would be replaced with a target group
      fixed_response  = {
        content_type = "text/plain"
        message_body = "Hello from ALB! This is a secure HTTPS response."
        status_code  = "200"
      }
    }
  }

  # DNS Configuration
  # Creates a Route 53 record pointing to the ALB
  route53_records = {
    # A record for the apex domain (e.g., example.com)
    A = {
      name    = ""  # Empty string means apex domain
      type    = "A"  # Address record type
      zone_id = aws_route53_zone.main.id  # Use the hosted zone created earlier
    }
  }

  # Apply the tags defined in locals
  tags = local.alb_tags
}
