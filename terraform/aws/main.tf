# Configuration du provider AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC Principal
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "3tier"
    Environment = "production"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  
  tags = {
    Name = "3tier-igw"
  }
}

# Sous-réseau Web (Frontend)
resource "aws_subnet" "web_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "subnetweb1"
    Tier = "web"
  }
}

# Sous-réseau App (Backend)
resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "subnetapp1"
    Tier = "app"
  }
}

# Sous-réseau Database
resource "aws_subnet" "db_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "subnetdb1"
    Tier = "database"
  }
}

# Route Table pour subnets publics
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  
  # Route vers Azure bastion
  route {
    cidr_block = "172.16.1.0/27"
    gateway_id = aws_vpn_gateway.vpn_gw.id
  }
  
  tags = {
    Name = "public-route-table"
  }
}

# Associations des route tables
resource "aws_route_table_association" "web_rta" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "app_rta" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "db_rta" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# VPN Gateway pour connexion IPSec avec Azure
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.main_vpc.id
  
  tags = {
    Name = "aws-vpn-gateway"
  }
}

# Customer Gateway (représentant Azure)
resource "aws_customer_gateway" "azure_cgw" {
  bgp_asn    = 65000
  ip_address = "20.20.20.20" # IP publique d'Azure (à remplacer)
  type       = "ipsec.1"
  
  tags = {
    Name = "azure-customer-gateway"
  }
}

# Connexion VPN
resource "aws_vpn_connection" "azure_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.azure_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true
  
  tags = {
    Name = "aws-azure-vpn"
  }
}

# Route VPN statique
resource "aws_vpn_connection_route" "azure_route" {
  vpn_connection_id      = aws_vpn_connection.azure_vpn.id
  destination_cidr_block = "172.16.1.0/27"
}

# Groupes de sécurité

# Groupe de sécurité Web
resource "aws_security_group" "web_sg" {
  name        = "WebTierSG"
  description = "Security group for web tier"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/27"] # Bastion Azure
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebTierSG"
  }
}

# Groupe de sécurité App
resource "aws_security_group" "app_sg" {
  name        = "PrivateInstanceSG"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/27"] # Bastion Azure
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PrivateInstanceSG"
  }
}

# Groupe de sécurité Database
resource "aws_security_group" "db_sg" {
  name        = "DBSG"
  description = "Security group for database tier"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/27"] # Bastion Azure
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DBSG"
  }
}

# Clés SSH
resource "aws_key_pair" "web_key" {
  key_name   = "clefront"
  public_key = file("~/.ssh/clefront.pub") # Chemin vers votre clé publique
}

resource "aws_key_pair" "app_key" {
  key_name   = "cleback"
  public_key = file("~/.ssh/cleback.pub")
}

resource "aws_key_pair" "db_key" {
  key_name   = "cledb"
  public_key = file("~/.ssh/cledb.pub")
}

# Instances EC2

# Instance Web (Frontend)
resource "aws_instance" "web_instance" {
  ami                    = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.web_key.key_name
  subnet_id              = aws_subnet.web_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd python3 python3-pip
    pip3 install ansible
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Frontend Server</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Frontend"
    Tier = "web"
  }
}

# Instance App (Backend)
resource "aws_instance" "app_instance" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.app_key.key_name
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-11-openjdk python3 python3-pip
    pip3 install ansible
    # Configuration application backend
  EOF

  tags = {
    Name = "Backend"
    Tier = "app"
  }
}

# Instance Database
resource "aws_instance" "db_instance" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.db_key.key_name
  subnet_id              = aws_subnet.db_subnet.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y mariadb-server python3 python3-pip
    pip3 install ansible
    systemctl start mariadb
    systemctl enable mariadb
  EOF

  tags = {
    Name = "DB1"
    Tier = "database"
  }
}

# Elastic IPs pour correspondre aux IPs données
resource "aws_eip" "frontend_eip" {
  instance = aws_instance.web_instance.id
  domain   = "vpc"
  
  tags = {
    Name = "Frontend-EIP"
  }
}

resource "aws_eip" "backend_eip" {
  instance = aws_instance.app_instance.id
  domain   = "vpc"
  
  tags = {
    Name = "Backend-EIP"
  }
}

resource "aws_eip" "db_eip" {
  instance = aws_instance.db_instance.id
  domain   = "vpc"
  
  tags = {
    Name = "DB-EIP"
  }
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "frontend_public_ip" {
  value = aws_eip.frontend_eip.public_ip
}

output "backend_public_ip" {
  value = aws_eip.backend_eip.public_ip
}

output "database_public_ip" {
  value = aws_eip.db_eip.public_ip
}

output "vpn_connection_id" {
  value = aws_vpn_connection.azure_vpn.id
}

output "subnets" {
  value = {
    web = aws_subnet.web_subnet.id
    app = aws_subnet.app_subnet.id
    db  = aws_subnet.db_subnet.id
  }
}
