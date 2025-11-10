variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (for bastion host)"
  type        = list(string)
  default     = []
}

variable "enable_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "EC2 key pair name for bastion host"
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet internet access (required for EMR to reach external repositories)"
  type        = bool
  default     = false
}

variable "custom_dns_servers" {
  description = "List of custom DNS server IPs for VPC DHCP options"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
