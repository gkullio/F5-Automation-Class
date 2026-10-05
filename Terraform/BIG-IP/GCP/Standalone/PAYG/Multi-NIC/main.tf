##################### Collect Public IP address #####################

data "http" "my_ip" {
  url                         = "https://checkip.amazonaws.com"
}

locals {
  my_public_ip                = "${chomp(data.http.my_ip.response_body)}/32"
}

# ---------------------------------------------------------------------------
# Network - three VPC networks (GCP requires each NIC in a different VPC)
# ---------------------------------------------------------------------------

module "gcp-vpc" {
  source                      = "./modules/gcp-vpc"

  mgmt_vpc_name               = var.mgmt_vpc_name
  mgmt_subnet_name            = var.mgmt_subnet_name
  mgmt_cidr                   = var.mgmt_cidr
  external_vpc_name           = var.external_vpc_name
  external_subnet_name        = var.external_subnet_name
  external_cidr               = var.external_cidr
  internal_vpc_name           = var.internal_vpc_name
  internal_subnet_name        = var.internal_subnet_name
  internal_cidr               = var.internal_cidr
  region                      = var.gcp_region
}

module "bigip" {
  source = "./modules/bigip"

  gcp_region                  = var.gcp_region
  gcp_zone                    = var.gcp_zone
  resourceOwner               = var.resourceOwner
  project_label               = var.project_name
  adminSrcAddr                = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
  REtrafficSrcAddr            = var.REtrafficSrcAddr
  vm_name                     = var.vm_name

  mgmt_vpc_self_link          = module.gcp-vpc.mgmt_vpc_self_link
  external_vpc_self_link      = module.gcp-vpc.external_vpc_self_link
  internal_vpc_self_link      = module.gcp-vpc.internal_vpc_self_link
  mgmt_subnet_self_link       = module.gcp-vpc.mgmt_subnet_self_link
  external_subnet_self_link   = module.gcp-vpc.external_subnet_self_link
  internal_subnet_self_link   = module.gcp-vpc.internal_subnet_self_link

  instance_prefix             = var.instance_prefix
  external_gw                 = var.external_gw

  bigip-hostname              = var.bigip-hostname
  ssh_publickey               = var.ssh_publickey
  machine_type                = var.machine_type
  f5_image_name               = var.f5_image_name
  f5_image_project            = var.f5_image_project
  f5_username                 = var.f5_username
  f5_username_2               = var.f5_username_2
  f5_password                 = var.f5_password
  dns_suffix                  = var.dns_suffix
  dns_server                  = var.dns_server
  ntp_server                  = var.ntp_server
  timezone                    = var.timezone
  script_name                 = var.script_name
  INIT_URL                    = var.INIT_URL
}