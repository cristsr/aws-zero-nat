# Local variables for VPC configuration
locals {
  # Base name for the VPC and related resources
  name = "zero-nat-vpc"

  # Environment designation for tagging and resource organization
  env  = "development"

  # Main CIDR block for the VPC - provides 65,536 IP addresses (10.0.0.0 to 10.0.255.255)
  vpc_cidr = "10.0.0.0/16"

  # Select the first two availability zones from the available list
  # Using only two AZs is a balance between high availability and cost efficiency
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Tags for route tables to identify their purpose and characteristics
  rt_tags = {
    # Public route table for ALB subnets - has direct internet access via IGW
    public = {
      Name        = "${local.name}-public-rt"
      Type        = "public"
      Purpose     = "ALB internet access"
      Environment = local.env
    }

    # Hybrid route table for application subnets
    # The key to Zero-NAT architecture - connects directly to IGW instead of NAT Gateway
    hybrid = {
      Name        = "${local.name}-hybrid-rt"
      Type        = "hybrid"
      Purpose     = "Outbound internet + VPC endpoints"
      Environment = local.env
    }

    # Private route table for database subnets - no internet access for security
    database = {
      Name        = "${local.name}-private-db-rt"
      Type        = "private"
      Purpose     = "Database isolation - no internet"
      Environment = local.env
    }
  }

  # Tags for subnet identification and purpose
  subnet_tags = {
    public = {
      Name = "${local.name}-public"
    }
    private = {
      Name = "${local.name}-hybrid"
    }
    database = {
      Name = "${local.name}-database"
    }
  }

  # Common tags for all VPC resources
  tags = {
    Name      = local.name
    ManagedBy = "terraform"
  }
}

# VPC Module Configuration
# Using the AWS VPC Terraform module to create the network infrastructure
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  # Use the name defined in locals
  name = local.name

  # Availability Zones from the data source in provider.tf
  azs = local.azs

  # Main CIDR block for the VPC
  cidr = local.vpc_cidr

  # Subnet CIDR calculations using cidrsubnet function
  # This creates non-overlapping subnet ranges within the VPC CIDR
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]       # e.g., 10.0.0.0/24, 10.0.1.0/24
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]   # e.g., 10.0.4.0/24, 10.0.5.0/24
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]   # e.g., 10.0.8.0/24, 10.0.9.0/24

  # ZERO-NAT CONFIGURATION - The crucial part!
  enable_nat_gateway      = false # NO NAT GATEWAYS! This is the key to cost savings
  enable_vpn_gateway      = false # No VPN needed for this architecture
  single_nat_gateway      = true  # Technical hack to allow one route table only
  map_public_ip_on_launch = false # Don't auto-assign public IPs to instances in public subnets

  # DNS configuration is essential for VPC endpoints to work properly
  # Allows instances to resolve AWS service endpoints and custom domains
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Internet Gateway - Required for the Zero-NAT architecture
  # This will be used directly by both public and private subnets
  create_igw = true

  # Database subnet configuration
  # Create a separate route table for database subnets with no internet access
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false # No internet access for databases
  create_database_nat_gateway_route      = false # No NAT gateway route for databases

  # Name for the default route table
  default_route_table_name = "${local.name}-default-rt"

  # Apply the route table tags defined in locals
  public_route_table_tags   = local.rt_tags.public
  private_route_table_tags  = local.rt_tags.hybrid
  database_route_table_tags = local.rt_tags.database

  # Subnet tags for identification and organization
  public_subnet_tags   = local.subnet_tags.public
  private_subnet_tags  = local.subnet_tags.private
  database_subnet_tags = local.subnet_tags.database

  # Apply common tags to all VPC resources
  tags = local.tags
}

# Custom route for private subnets - THE CORE OF ZERO-NAT ARCHITECTURE!
# This is what makes the Zero-NAT pattern work - connecting private subnets directly to the Internet Gateway
# Instead of using expensive NAT Gateways, we route private subnet traffic directly to the IGW
# Security is maintained through proper security groups and NACLs, not through network isolation
resource "aws_route" "private_internet_access" {
  # Create a route for each private subnet route table
  count = length(module.vpc.private_route_table_ids)

  # Associate with the private subnet route table
  route_table_id         = module.vpc.private_route_table_ids[count.index]

  # Route all outbound traffic (0.0.0.0/0) to the internet
  destination_cidr_block = "0.0.0.0/0"

  # Direct connection to the Internet Gateway - this is what saves NAT Gateway costs
  gateway_id             = module.vpc.igw_id
}
