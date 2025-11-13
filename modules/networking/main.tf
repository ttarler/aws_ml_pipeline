# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )

  lifecycle {
    # Ensure VPC is deleted last during destroy
    # Route tables, subnets, and other resources must be deleted first
    create_before_destroy = false
  }
}

# VPC DHCP Options (Custom DNS servers)
resource "aws_vpc_dhcp_options" "main" {
  count               = length(var.custom_dns_servers) > 0 ? 1 : 0
  domain_name_servers = var.custom_dns_servers

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-dhcp-options"
    }
  )
}

# Associate DHCP Options with VPC
resource "aws_vpc_dhcp_options_association" "main" {
  count           = length(var.custom_dns_servers) > 0 ? 1 : 0
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main[0].id
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-subnet-${count.index + 1}"
      Type = "Private"
    }
  )

  lifecycle {
    # Prevent accidental deletion and ensure proper cleanup order
    create_before_destroy = false
  }
}

# Public Subnets (for bastion host)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet-${count.index + 1}"
      Type = "Public"
    }
  )

  lifecycle {
    # Prevent accidental deletion and ensure proper cleanup order
    create_before_destroy = false
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count  = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw"
    }
  )

  lifecycle {
    # Ensure IGW is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  count  = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )

  lifecycle {
    # Ensure route table is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id

  lifecycle {
    # Ensure associations are deleted before route tables during destroy
    create_before_destroy = false
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway && length(var.public_subnet_cidrs) > 0 ? 1 : 0
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-eip"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway && length(var.public_subnet_cidrs) > 0 ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-gw"
    }
  )

  lifecycle {
    # Ensure NAT Gateway is deleted before subnets and VPC during destroy
    create_before_destroy = false
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-rt"
    }
  )

  lifecycle {
    # Ensure route table is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Route to NAT Gateway for private subnets
resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway && length(var.public_subnet_cidrs) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# Route Table Associations
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id

  lifecycle {
    # Ensure associations are deleted before route tables during destroy
    create_before_destroy = false
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  description            = "Security group for VPC endpoints"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-endpoints-sg"
    }
  )

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# VPC Endpoint for S3 (Gateway Endpoint)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-s3-endpoint"
    }
  )
}

# VPC Endpoint for SageMaker API
resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-api-endpoint"
    }
  )
}

# VPC Endpoint for SageMaker Runtime
resource "aws_vpc_endpoint" "sagemaker_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-runtime-endpoint"
    }
  )
}

# VPC Endpoint for SageMaker Studio
resource "aws_vpc_endpoint" "sagemaker_studio" {
  vpc_id              = aws_vpc.main.id
  service_name        = "aws.sagemaker.${var.aws_region}.studio"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-studio-endpoint"
    }
  )
}

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecr-api-endpoint"
    }
  )
}

# VPC Endpoint for ECR Docker
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecr-dkr-endpoint"
    }
  )
}

# VPC Endpoint for ECS
resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-endpoint"
    }
  )
}

# VPC Endpoint for ECS Agent
resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-agent-endpoint"
    }
  )
}

# VPC Endpoint for ECS Telemetry
resource "aws_vpc_endpoint" "ecs_telemetry" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-telemetry-endpoint"
    }
  )
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-logs-endpoint"
    }
  )
}

# VPC Endpoint for CloudWatch Monitoring
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-monitoring-endpoint"
    }
  )
}

# VPC Endpoint for STS
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sts-endpoint"
    }
  )
}

# VPC Endpoint for Secrets Manager (for storing credentials)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-secretsmanager-endpoint"
    }
  )
}

# VPC Endpoint for EC2 (needed for EMR)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ec2-endpoint"
    }
  )
}

# VPC Endpoint for EMR
resource "aws_vpc_endpoint" "emr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.elasticmapreduce"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-endpoint"
    }
  )
}

# Security Group for SageMaker
resource "aws_security_group" "sagemaker" {
  name_prefix            = "${var.project_name}-sagemaker-sg"
  description            = "Security group for SageMaker"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all TCP traffic within security group"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS for EFS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to internet for package downloads and API access"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP to internet for package downloads"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-sg"
    }
  )

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Security Group for EMR
resource "aws_security_group" "emr_master" {
  name_prefix = "${var.project_name}-emr-master-sg"
  description = "Security group for EMR master node"
  vpc_id      = aws_vpc.main.id

  # Revoke all rules before deleting to speed up cleanup
  revoke_rules_on_delete = true

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all TCP traffic within security group"
  }

  ingress {
    from_port       = 8998
    to_port         = 8998
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "Livy from SageMaker"
  }

  ingress {
    from_port       = 18888
    to_port         = 18888
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "SparkMagic from SageMaker"
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "HTTPS API access from SageMaker"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.enable_bastion && length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : []
    description = "SSH from bastion host"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for S3 access via Gateway Endpoint"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-master-sg"
    }
  )
}

resource "aws_security_group" "emr_slave" {
  name_prefix = "${var.project_name}-emr-slave-sg"
  description = "Security group for EMR core and task nodes"
  vpc_id      = aws_vpc.main.id

  # Revoke all rules before deleting to speed up cleanup
  revoke_rules_on_delete = true

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all TCP traffic within security group"
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master.id]
    description     = "All TCP from EMR master"
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "HTTPS API access from SageMaker"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for S3 access via Gateway Endpoint"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-slave-sg"
    }
  )
}

resource "aws_security_group" "emr_service" {
  name_prefix = "${var.project_name}-emr-service-sg"
  description = "Security group for EMR service access"
  vpc_id      = aws_vpc.main.id

  # Revoke all rules before deleting to speed up cleanup
  revoke_rules_on_delete = true

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "HTTPS API access from SageMaker"
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master.id]
    description     = "HTTPS API access from EMR master"
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_slave.id]
    description     = "HTTPS API access from EMR slave"
  }

  egress {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master.id]
    description     = "Service access to EMR master"
  }

  egress {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_slave.id]
    description     = "Service access to EMR slaves"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-service-sg"
    }
  )
}

# Add ingress rules to EMR security groups for service access
resource "aws_security_group_rule" "emr_master_service_ingress" {
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_service.id
  security_group_id        = aws_security_group.emr_master.id
  description              = "EMR service access"
}

resource "aws_security_group_rule" "emr_slave_service_ingress" {
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_service.id
  security_group_id        = aws_security_group.emr_slave.id
  description              = "EMR service access"
}

# Port 9443 ingress rules (separate to avoid circular dependencies)
resource "aws_security_group_rule" "emr_master_9443_from_service" {
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_service.id
  security_group_id        = aws_security_group.emr_master.id
  description              = "HTTPS API access from EMR service"
}

resource "aws_security_group_rule" "emr_slave_9443_from_service" {
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_service.id
  security_group_id        = aws_security_group.emr_slave.id
  description              = "HTTPS API access from EMR service"
}

# Security Group for ECS
resource "aws_security_group" "ecs" {
  name_prefix            = "${var.project_name}-ecs-sg"
  description            = "Security group for ECS tasks"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all TCP from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-sg"
    }
  )

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Security Group for Neptune
resource "aws_security_group" "neptune" {
  name_prefix = "${var.project_name}-neptune-sg"
  description = "Security group for Neptune graph database"
  vpc_id      = aws_vpc.main.id

  # Revoke all rules before deleting to speed up cleanup
  revoke_rules_on_delete = true

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }

  # Allow access from SageMaker
  ingress {
    from_port       = 8182
    to_port         = 8182
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
    description     = "Gremlin/SPARQL from SageMaker"
  }

  # Allow access from EMR master
  ingress {
    from_port       = 8182
    to_port         = 8182
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master.id]
    description     = "Gremlin/SPARQL from EMR master"
  }

  # Allow access from EMR slaves
  ingress {
    from_port       = 8182
    to_port         = 8182
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_slave.id]
    description     = "Gremlin/SPARQL from EMR slaves"
  }

  # Allow self-communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all TCP traffic within security group"
  }

  # Allow all outbound within VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all outbound within VPC"
  }

  # Allow HTTPS to VPC endpoints
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "HTTPS to VPC endpoints"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-sg"
    }
  )
}

# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  count                  = var.enable_bastion ? 1 : 0
  name                   = "${var.project_name}-bastion-sg"
  description            = "Security group for bastion host"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bastion-sg"
    }
  )

  lifecycle {
    # Ensure security group is deleted before VPC during destroy
    create_before_destroy = false
  }
}

# Bastion SSH Ingress Rule
resource "aws_security_group_rule" "bastion_ssh_ingress" {
  count             = var.enable_bastion ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "SSH from anywhere (restrict this in production)"
  security_group_id = aws_security_group.bastion[0].id
}

# Bastion ICMP Ingress Rule
resource "aws_security_group_rule" "bastion_icmp_ingress" {
  count             = var.enable_bastion ? 1 : 0
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ICMP ping from anywhere (for troubleshooting)"
  security_group_id = aws_security_group.bastion[0].id
}

# Bastion Egress Rule
resource "aws_security_group_rule" "bastion_egress" {
  count             = var.enable_bastion ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
  security_group_id = aws_security_group.bastion[0].id
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  count       = var.enable_bastion ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = data.aws_ami.amazon_linux_2023[0].id
  instance_type               = var.bastion_instance_type
  key_name                    = var.bastion_key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y ec2-instance-connect
              EOF

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bastion"
    }
  )

  depends_on = [
    aws_internet_gateway.main,
    aws_route_table.public,
    aws_route_table_association.public
  ]
}

# EFS Mount Target Cleanup Resource
# This ensures EFS mount targets are deleted before subnets during terraform destroy
# SageMaker Studio automatically creates EFS file systems that attach to private subnets
resource "null_resource" "efs_cleanup" {
  # Trigger recreation if VPC changes
  triggers = {
    vpc_id       = aws_vpc.main.id
    project_name = var.project_name
    region       = var.aws_region
  }

  # Cleanup EFS mount targets before destroying networking resources
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=========================================="
      echo "EFS Mount Target Cleanup"
      echo "=========================================="
      echo "Project: ${self.triggers.project_name}"
      echo "Region: ${self.triggers.region}"
      echo "VPC: ${self.triggers.vpc_id}"
      echo ""

      # Check if cleanup script exists
      if [ -f "${path.root}/scripts/cleanup-efs.sh" ]; then
        bash "${path.root}/scripts/cleanup-efs.sh" "${self.triggers.region}" "${self.triggers.project_name}" || true
      else
        echo "⚠️  EFS cleanup script not found. Attempting manual cleanup..."

        # Get VPC ID
        VPC_ID="${self.triggers.vpc_id}"

        # Find and delete mount targets in this VPC
        DELETED_COUNT=0
        aws efs describe-file-systems --region "${self.triggers.region}" --query 'FileSystems[*].FileSystemId' --output text 2>/dev/null | while read -r FS_ID; do
          if [ -n "$FS_ID" ]; then
            aws efs describe-mount-targets --region "${self.triggers.region}" --file-system-id "$FS_ID" --query 'MountTargets[*].[MountTargetId,SubnetId]' --output text 2>/dev/null | while IFS=$'\t' read -r MT_ID SUBNET_ID; do
              if [ -n "$MT_ID" ] && [ -n "$SUBNET_ID" ]; then
                MT_VPC=$(aws ec2 describe-subnets --region "${self.triggers.region}" --subnet-ids "$SUBNET_ID" --query 'Subnets[0].VpcId' --output text 2>/dev/null || echo "")
                if [ "$MT_VPC" = "$VPC_ID" ]; then
                  echo "🗑️  Deleting mount target: $MT_ID (EFS: $FS_ID, Subnet: $SUBNET_ID)"
                  aws efs delete-mount-target --region "${self.triggers.region}" --mount-target-id "$MT_ID" 2>/dev/null || true
                  DELETED_COUNT=$((DELETED_COUNT + 1))
                fi
              fi
            done
          fi
        done

        if [ $DELETED_COUNT -gt 0 ]; then
          echo ""
          echo "Deleted $DELETED_COUNT mount target(s)"
          echo "⏳ Waiting 45 seconds for mount targets to be fully deleted..."
          sleep 45
        else
          echo "✅ No mount targets found to delete"
        fi
      fi

      echo ""
      echo "✅ EFS cleanup complete"
      echo "=========================================="
    EOT
  }

  # This resource depends on private subnets, so during destroy:
  # 1. Compute resources (SageMaker, EMR) are destroyed first
  # 2. This null_resource is destroyed next (running the cleanup script)
  # 3. Private subnets are destroyed last
  depends_on = [
    aws_subnet.private
  ]
}

# VPC Resource Cleanup Coordinator
# This ensures all VPC-dependent resources (route tables, security groups, etc.)
# are deleted before the VPC during terraform destroy
resource "null_resource" "vpc_resource_cleanup" {
  # Trigger on VPC ID change
  triggers = {
    vpc_id = aws_vpc.main.id
  }

  # This resource depends on all VPC-dependent resources
  # During destroy, these will be deleted AFTER this null_resource is destroyed
  # This ensures proper ordering: VPC resources → subnets → VPC
  depends_on = [
    # Route tables and associations
    aws_route_table.public,
    aws_route_table.private,
    aws_route_table_association.public,
    aws_route_table_association.private,
    aws_route.private_nat_gateway,

    # Security groups
    aws_security_group.vpc_endpoints,
    aws_security_group.sagemaker,
    aws_security_group.emr_master,
    aws_security_group.emr_slave,
    aws_security_group.emr_service,
    aws_security_group.ecs,
    aws_security_group.neptune,
    aws_security_group.bastion,

    # Gateways
    aws_nat_gateway.main,
    aws_internet_gateway.main
  ]
}
