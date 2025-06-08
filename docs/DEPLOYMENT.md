# Deployment Guide for AWS Zero-NAT Architecture

This document provides step-by-step instructions for deploying the Zero-NAT architecture using Terraform.

## Prerequisites

Before you begin, ensure you have the following:

1. **AWS Account**: Active AWS account with appropriate permissions
2. **Terraform**: Installed (version ~> 1.0)
3. **AWS CLI**: Configured with appropriate credentials
4. **Domain Name**: Registered domain name (if you plan to use the ALB with HTTPS)

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/cristsr/aws-zero-nat.git
cd aws-zero-nat
```

### 2. Configure Variables

Review and update the variables in `variables.tf`:

```hcl
# AWS Region Variable
variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"  # Change to your preferred region
}

# Domain Name Variable
variable "domain_name" {
  description = "The domain name to use for the application"
  type        = string
  default     = "example.com"  # Change to your domain
}
```

### 3. Initialize Terraform

Initialize Terraform to download the required providers and modules:

```bash
terraform init
```

### 4. Review the Deployment Plan

Generate and review the execution plan to understand what resources will be created:

```bash
terraform plan
```

Review the output carefully to ensure it aligns with your expectations.

### 5. Apply the Configuration

Deploy the infrastructure:

```bash
terraform apply
```

When prompted, type `yes` to confirm the deployment.

### 6. Configure DNS

After the deployment completes, Terraform will output the nameservers for your Route 53 hosted zone:

```
nameservers = [
  "ns-1234.awsdns-12.org",
  "ns-567.awsdns-34.com",
  "ns-890.awsdns-56.net",
  "ns-1234.awsdns-78.co.uk"
]
```

Configure these nameservers at your domain registrar to delegate DNS management to Route 53.

### 7. Verify the Deployment

1. **Check VPC and Subnets**:
   - Verify that the VPC and subnets have been created with the correct CIDR ranges
   - Confirm that the route tables are configured correctly

2. **Verify ALB Configuration**:
   - Check that the ALB is properly configured and healthy
   - Verify that the HTTPS listener is using the correct certificate

3. **Test Connectivity**:
   - Deploy a test instance in the hybrid subnet
   - Verify that it can access the internet directly through the IGW
   - Confirm that security groups are properly restricting traffic

## Advanced Configuration

### Customizing CIDR Blocks

To customize the CIDR blocks, modify the `locals` block in `vpc.tf`:

```hcl
locals {
  # Base name for the VPC and related resources
  name = "zero-nat-vpc"
  
  # Environment designation for tagging and resource organization
  env  = "development"
  
  # Main CIDR block for the VPC
  vpc_cidr = "10.0.0.0/16"  # Modify this for your network
  
  # Select availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # ... other locals ...
}
```

### Adding Application Resources

To deploy applications in the hybrid subnets:

1. Create a new Terraform file (e.g., `ecs.tf` or `ec2.tf`)
2. Configure the resources to use the hybrid subnets:

```hcl
# Example EC2 instance in hybrid subnet
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnets[0]  # Use hybrid subnet
  
  # Security group configuration
  vpc_security_group_ids = [aws_security_group.app.id]
  
  tags = {
    Name = "AppServer"
  }
}

# Security group for application
resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Security group for application servers"
  vpc_id      = module.vpc.vpc_id
  
  # Allow inbound traffic from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }
  
  # Allow outbound HTTPS for API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Adding Database Resources

To deploy databases in the private subnets:

```hcl
# Example RDS instance in private subnet
resource "aws_db_instance" "database" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "admin"
  password             = "password"  # Use AWS Secrets Manager in production
  parameter_group_name = "default.mysql8.0"
  
  # Use database subnet group
  db_subnet_group_name = module.vpc.database_subnet_group_name
  
  # Security group configuration
  vpc_security_group_ids = [aws_security_group.db.id]
  
  # Disable public accessibility
  publicly_accessible = false
  
  tags = {
    Name = "Database"
  }
}

# Security group for database
resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Security group for database servers"
  vpc_id      = module.vpc.vpc_id
  
  # Allow inbound traffic from application security group only
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  
  # No outbound internet access needed
}
```

## Troubleshooting

### Common Issues

1. **DNS Not Working**:
   - Verify that nameservers are correctly configured at your domain registrar
   - Check that the Route 53 hosted zone is correctly configured

2. **ALB Health Checks Failing**:
   - Verify that security groups allow traffic on the health check port
   - Check that the target instances or services are running and responding

3. **Instances Can't Access Internet**:
   - Verify that the route table for hybrid subnets has a route to the IGW
   - Check that security groups allow outbound traffic
   - Verify that the IGW is correctly attached to the VPC

4. **Certificate Validation Issues**:
   - Ensure DNS validation records are correctly created in Route 53
   - Wait for certificate validation to complete (can take up to 30 minutes)

### Debugging Tips

1. **VPC Flow Logs**:
   Enable VPC Flow Logs to troubleshoot connectivity issues:

   ```hcl
   resource "aws_flow_log" "vpc_flow_log" {
     log_destination      = aws_cloudwatch_log_group.flow_log.arn
     log_destination_type = "cloud-watch-logs"
     traffic_type         = "ALL"
     vpc_id               = module.vpc.vpc_id
   }
   
   resource "aws_cloudwatch_log_group" "flow_log" {
     name = "/aws/vpc-flow-log/${module.vpc.vpc_id}"
   }
   ```

2. **EC2 Instance Connect**:
   Use EC2 Instance Connect to access instances in hybrid subnets for troubleshooting.

3. **CloudWatch Metrics**:
   Monitor ALB metrics in CloudWatch to identify performance or connectivity issues.

## Cleanup

To destroy the infrastructure when no longer needed:

```bash
terraform destroy
```

When prompted, type `yes` to confirm the destruction of all resources.

## Security Best Practices

1. **Least Privilege**: Use IAM roles with minimal permissions for all resources
2. **Encryption**: Enable encryption for all data at rest and in transit
3. **Security Groups**: Define minimal inbound/outbound rules
4. **Monitoring**: Enable CloudTrail and CloudWatch for monitoring and alerting
5. **Updates**: Regularly update all systems and dependencies
