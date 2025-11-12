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
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
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
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

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
  name_prefix = "${var.project_name}-sagemaker-sg"
  description = "Security group for SageMaker"
  vpc_id      = aws_vpc.main.id

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
}

# Security Group for EMR
resource "aws_security_group" "emr_master" {
  name_prefix = "${var.project_name}-emr-master-sg"
  description = "Security group for EMR master node"
  vpc_id      = aws_vpc.main.id

  # Revoke all rules before deleting to speed up cleanup
  revoke_rules_on_delete = true

  lifecycle {
    create_before_destroy = true
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
    create_before_destroy = true
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
    create_before_destroy = true
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
  name_prefix = "${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

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
}

# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bastion-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
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
