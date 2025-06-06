terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Variables déclarations
variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-1"
}

variable "azure_vpn_ip" {
  description = "IP publique du VPN Gateway Azure"
  type        = string
}

variable "azure_bastion_ip" {
  description = "IP du bastion Azure"
  type        = string
}

variable "vpn_key" {
  description = "Clé pré-partagée pour le VPN IPSec"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "energy-hybrid"
}

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# Subnets
resource "aws_subnet" "frontend" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-frontend-subnet"
    Tier    = "frontend"
    Project = var.project_name
  }
}

resource "aws_subnet" "backend" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name    = "${var.project_name}-backend-subnet"
    Tier    = "backend"
    Project = var.project_name
  }
}

resource "aws_subnet" "database" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name    = "${var.project_name}-database-subnet"
    Tier    = "database"
    Project = var.project_name
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # Route vers Azure via VPN
  route {
    cidr_block = "172.16.0.0/16"
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Route vers Azure via VPN
  route {
    cidr_block = "172.16.0.0/16"
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

# Route Table Associations
resource "aws_route_table_association" "frontend" {
  subnet_id      = aws_subnet.frontend.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "backend" {
  subnet_id      = aws_subnet.backend.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  subnet_id      = aws_subnet.database.id
  route_table_id = aws_route_table.private.id
}

# ========== CONFIGURATION VPN ==========

# Customer Gateway (représente Azure)
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65000
  ip_address = var.azure_vpn_ip
  type       = "ipsec.1"

  tags = {
    Name    = "${var.project_name}-azure-cgw"
    Project = var.project_name
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-vpn-gw"
    Project = var.project_name
  }
}

# VPN Connection vers Azure
resource "aws_vpn_connection" "azure" {
  customer_gateway_id = aws_customer_gateway.azure.id
  type               = "ipsec.1"
  static_routes_only = true
  vpn_gateway_id     = aws_vpn_gateway.main.id

  # Tunnel 1 configuration
  tunnel1_preshared_key = var.vpn_key
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA256"]
  tunnel1_phase1_dh_group_numbers     = [14]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA256"]
  tunnel1_phase2_dh_group_numbers     = [14]

  # Tunnel 2 configuration (redondance)
  tunnel2_preshared_key = var.vpn_key
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA256"]
  tunnel2_phase1_dh_group_numbers     = [14]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA256"]
  tunnel2_phase2_dh_group_numbers     = [14]

  tags = {
    Name    = "${var.project_name}-vpn-connection"
    Project = var.project_name
  }
}

# Route statique vers Azure
resource "aws_vpn_connection_route" "azure" {
  vpn_connection_id      = aws_vpn_connection.azure.id
  destination_cidr_block = "172.16.0.0/16"
}


