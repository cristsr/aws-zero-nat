locals {
  name = "zero-nat-vpc"
  env  = "development"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_names = [
    for i, az in local.azs : "public-alb-${substr(az, -1, 1)}"
  ]

  private_subnet_names = [
    for i, az in local.azs : "hybrid-app-${substr(az, -1, 1)}"
  ]

  database_subnet_names = [
    for i, az in local.azs : "private-db-${substr(az, -1, 1)}"
  ]

  rt_tags = {
    public = {
      Name        = "${local.name}-public-rt"
      Type        = "public"
      Purpose     = "ALB internet access"
      Environment = local.env
    }

    hybrid = {
      Name        = "${local.name}-hybrid-rt"
      Type        = "hybrid"
      Purpose     = "Outbound internet + VPC endpoints"
      Environment = local.env
    }

    database = {
      Name        = "${local.name}-private-db-rt"
      Type        = "private"
      Purpose     = "Database isolation - no internet"
      Environment = local.env
    }
  }

  tags = {
    Name      = local.name
    Terraform = "true"
  }
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name

  azs = local.azs

  cidr = local.vpc_cidr

  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]

  # ZERO-NAT CONFIGURATION - ¡La parte crucial!
  enable_nat_gateway      = false # <-¡NO NAT GATEWAYS!
  enable_vpn_gateway      = false # <- No VPN needed
  single_nat_gateway      = true  # <-Hack to allow one table only
  map_public_ip_on_launch = false # <- Default is false

  # DNS is crucial for VPC endpoints
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Internet Gateway - Needed for outbound access
  create_igw = true

  # Database isolation
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  default_route_table_name = "${local.name}-default-rt"

  # Configure VPC Flow Logs (useful for debugging traffic)
  enable_flow_log = false
  # create_flow_log_cloudwatch_log_group = true
  # create_flow_log_cloudwatch_iam_role  = true
  # flow_log_destination_type            = "cloud-watch-logs" // Can be s3, kinesis-data-firehose or cloud-watch-logs

  public_route_table_tags   = local.rt_tags.public
  private_route_table_tags  = local.rt_tags.hybrid
  database_route_table_tags = local.rt_tags.database

  tags = local.tags
}

# Custom route for private subnets - THE MAGIC!
# Connect the "private subnets" to IGW to allow traffic I/O
# The security comes from configuring SG with ACLs
resource "aws_route" "private_internet_access" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc.igw_id
}

# Custom tags for subnets
resource "aws_ec2_tag" "public_subnet_names" {
  count = length(module.vpc.public_subnets)

  resource_id = module.vpc.public_subnets[count.index]
  key         = "Name"
  value       = local.public_subnet_names[count.index]
}

resource "aws_ec2_tag" "private_subnet_names" {
  count = length(module.vpc.private_subnets)

  resource_id = module.vpc.private_subnets[count.index]
  key         = "Name"
  value       = local.private_subnet_names[count.index]
}

resource "aws_ec2_tag" "database_subnet_names" {
  count = length(module.vpc.database_subnets)

  resource_id = module.vpc.database_subnets[count.index]
  key         = "Name"
  value       = local.database_subnet_names[count.index]
}

# Tags adicionales para las subnets (opcional)
resource "aws_ec2_tag" "public_subnet_type" {
  count = length(module.vpc.public_subnets)

  resource_id = module.vpc.public_subnets[count.index]
  key         = "Type"
  value       = "public"
}

resource "aws_ec2_tag" "public_subnet_purpose" {
  count = length(module.vpc.public_subnets)

  resource_id = module.vpc.public_subnets[count.index]
  key         = "Purpose"
  value       = "ALB"
}

resource "aws_ec2_tag" "private_subnet_type" {
  count = length(module.vpc.private_subnets)

  resource_id = module.vpc.private_subnets[count.index]
  key         = "Type"
  value       = "hybrid"
}

resource "aws_ec2_tag" "private_subnet_purpose" {
  count = length(module.vpc.private_subnets)

  resource_id = module.vpc.private_subnets[count.index]
  key         = "Purpose"
  value       = "ECS-apps"
}

resource "aws_ec2_tag" "database_subnet_type" {
  count = length(module.vpc.database_subnets)

  resource_id = module.vpc.database_subnets[count.index]
  key         = "Type"
  value       = "private"
}

resource "aws_ec2_tag" "database_subnet_purpose" {
  count = length(module.vpc.database_subnets)

  resource_id = module.vpc.database_subnets[count.index]
  key         = "Purpose"
  value       = "RDS"
}

