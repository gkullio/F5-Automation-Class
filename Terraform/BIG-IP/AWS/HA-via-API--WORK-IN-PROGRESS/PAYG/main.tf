##################### Collect Public IP address #####################

data "http" "my_ip" {
  url                         = "https://checkip.amazonaws.com"
}


locals {
  my_public_ip                = "${chomp(data.http.my_ip.response_body)}/32"

  # Resolve VPC and subnet IDs — either from the created module or from existing IDs
  vpc_id                      = var.use_existing_vpc ? var.existing_vpc_id             : module.aws-vpc[0].vpc_id
  mgmt_subnet_id              = var.use_existing_vpc ? var.existing_mgmt_subnet_id     : module.aws-vpc[0].mgmt_subnet_id
  external_subnet_id          = var.use_existing_vpc ? var.existing_external_subnet_id : module.aws-vpc[0].external_subnet_id
  internal_subnet_id          = var.use_existing_vpc ? var.existing_internal_subnet_id : module.aws-vpc[0].internal_subnet_id
}

# ---------------------------------------------------------------------------
# Network — three subnets: management, external, internal
# Skipped when use_existing_vpc = true
# ---------------------------------------------------------------------------

module "aws-vpc" {
  source                      = "./modules/aws-vpc"
  count                       = var.use_existing_vpc ? 0 : 1

  vpc_name                    = var.vpc_name
  vpc_cidr                    = var.vpc_cidr
  mgmt_subnet_name            = var.mgmt_subnet_name
  mgmt_cidr                   = var.mgmt_cidr
  external_subnet_name        = var.external_subnet_name
  external_cidr               = var.external_cidr
  internal_subnet_name        = var.internal_subnet_name
  internal_cidr               = var.internal_cidr
  availability_zone           = var.availability_zone
}

# ---------------------------------------------------------------------------
# BIG-IP HA pair with Cloud Failover Extension
# ---------------------------------------------------------------------------

module "bigip" {
  source                      = "./modules/bigip"

  aws_region                  = var.aws_region
  resourceOwner               = var.resourceOwner
  adminSrcAddr                = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
  REtrafficSrcAddr            = var.REtrafficSrcAddr
  vm_name_1                   = var.vm_name_1
  vm_name_2                   = var.vm_name_2
  vpc_id                      = local.vpc_id
  vpc_cidr                    = var.vpc_cidr
  mgmt_subnet_id              = local.mgmt_subnet_id
  external_subnet_id          = local.external_subnet_id
  internal_subnet_id          = local.internal_subnet_id
  instance_prefix             = var.instance_prefix
  external_gw                 = var.external_gw
  cfe_label                   = var.cfe_label
  create_external_eips        = var.create_external_eips

  # BIG-IP VE variables
  bigip_hostname_1            = var.bigip_hostname_1
  bigip_hostname_2            = var.bigip_hostname_2
  ssh_publickey               = var.ssh_publickey
  instance_size               = var.instance_size
  f5_ami_search_name          = var.f5_ami_search_name
  f5_ami_owner                = var.f5_ami_owner
  f5_username                 = var.f5_username
  f5_username_2               = var.f5_username_2
  f5_password                 = var.f5_password
  dns_suffix                  = var.dns_suffix
  dns_server                  = var.dns_server
  ntp_server                  = var.ntp_server
  timezone                    = var.timezone
  INIT_URL                    = var.INIT_URL
}
