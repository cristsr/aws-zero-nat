# AWS Zero-NAT Architecture - Detailed Design Document

This document provides a detailed technical explanation of the Zero-NAT architecture implemented in this project.

## Architecture Diagram

```
                                  Internet
                                      |
                                      ▼
                                 [Route 53]
                                      |
                                      ▼
                              Internet Gateway
                                     / \
                                    /   \
                                   /     \
                                  /       \
                                 ▼         ▼
┌───────────────────────┐   ┌───────────────────────┐
│   Public Subnet AZ-a  │   │   Public Subnet AZ-b  │
│   (10.0.0.0/24)       │   │   (10.0.1.0/24)       │
│                       │   │                       │
│  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │ Application     │  │   │  │ Application     │  │
│  │ Load Balancer   │◄─┼───┼──┤ Load Balancer   │  │
│  │ (ALB)           │  │   │  │ (ALB)           │  │
│  └─────────────────┘  │   │  └─────────────────┘  │
└───────────┬───────────┘   └───────────┬───────────┘
            │                           │
            ▼                           ▼
┌───────────────────────┐   ┌───────────────────────┐
│   Hybrid Subnet AZ-a  │   │   Hybrid Subnet AZ-b  │
│   (10.0.4.0/24)       │   │   (10.0.5.0/24)       │
│                       │   │                       │
│  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │ Application     │  │   │  │ Application     │  │
│  │ Servers         │◄─┼───┼──┤ Servers         │  │
│  │ (ECS/EC2)       │  │   │  │ (ECS/EC2)       │  │
│  └─────────────────┘  │   │  └─────────────────┘  │
│         │             │   │         │             │
│         │             │   │         │             │
│         ▼             │   │         ▼             │
│  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │ Security Group  │  │   │  │ Security Group  │  │
│  └─────────────────┘  │   │  └─────────────────┘  │
└───────────┬───────────┘   └───────────┬───────────┘
            │                           │
            ▼                           ▼
┌───────────────────────┐   ┌───────────────────────┐
│  Private Subnet AZ-a  │   │  Private Subnet AZ-b  │
│  (10.0.8.0/24)        │   │  (10.0.9.0/24)        │
│                       │   │                       │
│  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │ Database        │  │   │  │ Database        │  │
│  │ Servers (RDS)   │◄─┼───┼──┤ Servers (RDS)   │  │
│  └─────────────────┘  │   │  └─────────────────┘  │
└───────────────────────┘   └───────────────────────┘
```

## Routing Configuration - The Key to Zero-NAT

### Traditional Architecture Routing

In a traditional AWS architecture:

1. **Public Subnets**:
   - Route table has a route to the Internet Gateway for 0.0.0.0/0
   - Resources have public IPs

2. **Private Subnets**:
   - Route table has a route to the NAT Gateway for 0.0.0.0/0
   - Resources have only private IPs
   - NAT Gateway provides outbound internet access

### Zero-NAT Architecture Routing

In our Zero-NAT architecture:

1. **Public Subnets** (for ALB):
   - Route table has a route to the Internet Gateway for 0.0.0.0/0
   - Resources have public IPs
   - Standard configuration, no changes

2. **Hybrid Subnets** (for Application Tier):
   - Route table has a direct route to the Internet Gateway for 0.0.0.0/0
   - Resources have public IPs but are protected by security groups
   - **This is the key difference** - bypassing NAT Gateways entirely

3. **Private Subnets** (for Database Tier):
   - Route table has no route to the internet
   - Resources have only private IPs
   - Completely isolated from the internet

## Route Table Configurations

### Public Route Table
```hcl
# Managed by the VPC module
resource "aws_route_table" "public" {
  vpc_id = module.vpc.vpc_id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.vpc.igw_id
  }
  
  tags = local.rt_tags.public
}
```

### Hybrid Route Table
```hcl
# Managed by the VPC module with custom route
resource "aws_route_table" "hybrid" {
  vpc_id = module.vpc.vpc_id
  
  tags = local.rt_tags.hybrid
}

# The key to Zero-NAT architecture - direct route to IGW
resource "aws_route" "private_internet_access" {
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc.igw_id
}
```

### Private Route Table
```hcl
# Managed by the VPC module
resource "aws_route_table" "database" {
  vpc_id = module.vpc.vpc_id
  
  # No route to the internet
  
  tags = local.rt_tags.database
}
```

## Security Implementation

### Security Groups

Security groups are the primary defense mechanism in the Zero-NAT architecture:

1. **ALB Security Group**:
   - Inbound: Allow HTTP/HTTPS from the internet
   - Outbound: Restrict to VPC CIDR only

2. **Application Security Group**:
   - Inbound: Allow traffic only from the ALB security group
   - Outbound: Allow only necessary connections (e.g., HTTPS for API calls)

3. **Database Security Group**:
   - Inbound: Allow traffic only from the application security group
   - Outbound: No outbound rules needed

### Network ACLs

Network ACLs provide an additional layer of security:

1. **Public Subnet NACLs**:
   - Standard configuration for web traffic

2. **Hybrid Subnet NACLs**:
   - Carefully configured to allow only necessary outbound traffic
   - Block common attack vectors

3. **Private Subnet NACLs**:
   - Strict rules allowing only database traffic from application tier

## Technical Implementation Details

### VPC Module Configuration

The VPC is created using the AWS VPC Terraform module with specific configurations:

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  # Basic configuration
  name = local.name
  cidr = local.vpc_cidr
  azs  = local.azs
  
  # Subnet configuration
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]
  
  # Zero-NAT configuration
  enable_nat_gateway = false
  single_nat_gateway = true
  create_igw         = true
  
  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

### Custom Route for Hybrid Subnets

The custom route that enables the Zero-NAT architecture:

```hcl
resource "aws_route" "private_internet_access" {
  count = length(module.vpc.private_route_table_ids)
  
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc.igw_id
}
```

## Comparison with Traditional Architecture

### Traditional Three-Tier Architecture

```
Internet → Internet Gateway → Public Subnet (ALB) → NAT Gateway → Private Subnet (App) → Private Subnet (DB)
```

### Zero-NAT Architecture

```
Internet → Internet Gateway → Public Subnet (ALB)
                           ↓
                           → Hybrid Subnet (App) → Private Subnet (DB)
```

## Cost Analysis

### Traditional Architecture Costs

- **NAT Gateway**: $0.045 per hour × 24 hours × 30 days = $32.40 per month per NAT Gateway
- **Data Processing**: $0.045 per GB processed
- **High Availability**: Requires one NAT Gateway per AZ, doubling the cost

### Zero-NAT Architecture Costs

- **NAT Gateway**: $0 (eliminated)
- **Data Processing**: Same data processing costs, but through the Internet Gateway instead
- **High Availability**: Maintained through multiple AZs without additional NAT Gateway costs

## Implementation Considerations

### When to Use Zero-NAT

- Development and testing environments
- Cost-sensitive production workloads
- Applications with proper security group configurations
- Modern cloud-native applications

### When Not to Use Zero-NAT

- Highly regulated environments requiring complete network isolation
- Legacy applications that rely on network-level security
- Environments where instances must never have public IP addresses

## Best Practices for Zero-NAT Implementation

1. **Strict Security Groups**: Define minimal inbound/outbound rules
2. **Regular Security Audits**: Monitor and review security configurations
3. **Network Traffic Monitoring**: Implement CloudWatch and VPC Flow Logs
4. **Proper Application Security**: Don't rely solely on network-level security
5. **Regular Updates**: Keep all systems patched and updated
