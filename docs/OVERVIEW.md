# AWS Zero-NAT Architecture

This project implements a cost-effective AWS VPC architecture that eliminates the need for NAT Gateways while maintaining secure outbound internet access for private resources.

## Architecture Overview

```
us-east-1a:              us-east-1b:
┌─────────────────┐     ┌─────────────────┐
│ public-alb-a    │     │ public-alb-b    │  
│ (ALB tier)      │     │ (ALB tier)      │
└─────────────────┘     └─────────────────┘
↕                       ↕
Internet Gateway (FREE)
↕                       ↕
┌─────────────────┐     ┌─────────────────┐
│ hybrid-app-a    │     │ hybrid-app-b    │
│ (ECS tier)      │     │ (ECS tier)      │
└─────────────────┘     └─────────────────┘
│                       │
VPC Internal Only
│                       │  
┌─────────────────┐     ┌─────────────────┐
│ private-db-a    │     │ private-db-b    │
│ (RDS tier)      │     │ (RDS tier)      │
└─────────────────┘     └─────────────────┘
```

## What is Zero-NAT Architecture?

Traditional AWS architectures place private resources in subnets that use NAT Gateways for outbound internet access. While secure, NAT Gateways are expensive ($0.045/hour + data processing fees).

Zero-NAT architecture eliminates NAT Gateways by:
1. Creating a "hybrid" subnet tier that connects directly to the Internet Gateway
2. Using security groups and NACLs for security instead of network isolation
3. Maintaining a truly private subnet tier for sensitive resources like databases

## Key Components

### VPC Configuration
- **CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **Availability Zones**: 2 AZs for high availability with cost control
- **Subnet Tiers**:
  - **Public Subnets**: For ALBs with direct internet access (10.0.0.0/24, 10.0.1.0/24)
  - **Hybrid Subnets**: For application tier with direct IGW access (10.0.4.0/24, 10.0.5.0/24)
  - **Private Subnets**: For databases with no internet access (10.0.8.0/24, 10.0.9.0/24)

### Internet Gateway
- Single IGW providing free internet connectivity
- Connected to both public and hybrid subnets
- Replaces costly NAT Gateways

### Route Tables
- **Public Route Table**: Standard configuration with IGW for inbound/outbound traffic
- **Hybrid Route Table**: The key to Zero-NAT - connects directly to IGW instead of NAT Gateway
- **Private Route Table**: No internet routes for maximum database security

### Application Load Balancer
- Deployed in public subnets
- Handles HTTP/HTTPS traffic with automatic redirection to HTTPS
- Uses ACM certificate for TLS termination
- Restricted outbound traffic to VPC CIDR for security

### DNS Configuration
- Route 53 hosted zone for domain management
- ACM certificate with wildcard coverage for secure connections

## Cost Benefits

| Resource | Traditional Architecture | Zero-NAT Architecture | Monthly Savings |
|----------|--------------------------|----------------------|----------------|
| NAT Gateway | $32.40 per NAT × 2 AZs = $64.80 | $0 | $64.80 |
| Data Processing | ~$45 for 1TB outbound | ~$45 for 1TB outbound | $0 |
| **Total** | **~$109.80** | **~$45** | **~$64.80** |

*Prices based on us-east-1 region. Data processing costs remain the same but are now handled by the IGW instead of NAT Gateways.*

## Security Considerations

The Zero-NAT architecture maintains security through:

1. **Security Groups**: Strict inbound/outbound rules for all resources
2. **Network ACLs**: Additional network-level filtering
3. **Subnet Isolation**: Truly private subnet for sensitive database resources
4. **TLS Encryption**: All external traffic encrypted with HTTPS

## Deployment Instructions

1. Ensure you have Terraform installed (version ~> 1.0)
2. Clone this repository
3. Update the `domain_name` variable in `variables.tf` if needed
4. Initialize Terraform:
   ```
   terraform init
   ```
5. Review the deployment plan:
   ```
   terraform plan
   ```
6. Apply the configuration:
   ```
   terraform apply
   ```
7. Configure your domain registrar with the Route 53 nameservers from the output

## Limitations and Considerations

- Application instances in hybrid subnets have public IP addresses but are protected by security groups
- Not suitable for environments with strict compliance requirements that mandate complete network isolation
- Works best for modern, cloud-native applications that use proper security groups

## When to Use Zero-NAT Architecture

- Development and testing environments
- Cost-sensitive production workloads
- Startups and small businesses
- Any scenario where NAT Gateway costs are a concern

## When to Use Traditional NAT Architecture

- Highly regulated environments with strict compliance requirements
- Scenarios where instances must never have public IP addresses
- Enterprise environments where cost is less important than maximum isolation
