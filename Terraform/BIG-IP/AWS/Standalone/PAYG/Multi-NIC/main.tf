##################### Collect Public IP address #####################

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}


locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

# ---------------------------------------------------------------------------
# Network — three subnets: management, external, internal
# ---------------------------------------------------------------------------

module "aws-vpc" {
  source = "./modules/aws-vpc"

  vpc_name              = var.vpc_name
  vpc_cidr              = var.vpc_cidr
  mgmt_subnet_name      = var.mgmt_subnet_name
  mgmt_cidr             = var.mgmt_cidr
  external_subnet_name  = var.external_subnet_name
  external_cidr         = var.external_cidr
  internal_subnet_name  = var.internal_subnet_name
  internal_cidr         = var.internal_cidr
  availability_zone     = var.availability_zone
}

module "bigip" {
  source = "./modules/bigip"

  aws_region       = var.aws_region
  resourceOwner    = var.resourceOwner
  adminSrcAddr     = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
  REtrafficSrcAddr = var.REtrafficSrcAddr
  vm_name          = var.vm_name
  vpc_id           = module.aws-vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  mgmt_subnet_id     = module.aws-vpc.mgmt_subnet_id
  external_subnet_id = module.aws-vpc.external_subnet_id
  internal_subnet_id = module.aws-vpc.internal_subnet_id
  instance_prefix    = var.instance_prefix
  external_gw        = var.external_gw

  # BIG-IP VE variables
  bigip-hostname     = var.bigip-hostname
  ssh_publickey      = var.ssh_publickey
  instance_size      = var.instance_size
  f5_ami_search_name = var.f5_ami_search_name
  f5_ami_owner       = var.f5_ami_owner
  f5_username        = var.f5_username
  f5_username_2      = var.f5_username_2
  f5_password        = var.f5_password
  dns_suffix         = var.dns_suffix
  dns_server         = var.dns_server
  ntp_server         = var.ntp_server
  timezone           = var.timezone
  script_name        = var.script_name
  INIT_URL           = var.INIT_URL
}
