# Configuration pour environnement dev
aws_region     = "us-east-1"
environment    = "dev"
instance_type  = "t2.micro"

azure_bastion_ip = "172.16.1.4/27"
azure_vpn_ip = "128.203.68.163"
azure_vnet_cidr = "172.16.0.0/16"
vpn_key        = "Gdg59G5SG,;g:d,SGIDSJ9548!"
project_name   = "VPN"

allowed_ssh_cidrs = [
  "0.0.0.0/0"," 91.175.22.245/32"
]


