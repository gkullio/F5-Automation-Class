##################### Collect Public IP address #####################

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip        = chomp(data.http.my_ip.response_body)
  my_public_ip = "${local.my_ip}/32"
  my_ip_in_vpn = anytrue([
    for cidr in var.vpnMgmtSrcAddr :
    try(
      cidrhost("${local.my_ip}/${strcontains(cidr, "/") ? split("/", cidr)[1] : "32"}", 0) == cidrhost(strcontains(cidr, "/") ? cidr : "${cidr}/32", 0),
      false
    )
  ])
  my_ip_in_re = anytrue([
    for cidr in var.REtrafficSrcAddr :
    try(
      cidrhost("${local.my_ip}/${strcontains(cidr, "/") ? split("/", cidr)[1] : "32"}", 0) == cidrhost(strcontains(cidr, "/") ? cidr : "${cidr}/32", 0),
      false
    )
  ])
  adminSrcAddr     = local.my_ip_in_vpn ? var.vpnMgmtSrcAddr : concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
  REtrafficSrcAddr = local.my_ip_in_re  ? var.REtrafficSrcAddr : concat(var.REtrafficSrcAddr, [local.my_public_ip])
  tags = {
    owner = var.resourceOwner
    email = var.ownerEmail
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

module "gcp-vpc" {
  source = "./modules/gcp-vpc"

  vpc_name         = var.vpc_name
  mgmt_subnet_name = var.mgmt_subnet_name
  mgmt_cidr        = var.mgmt_cidr
  region           = var.gcp_region
}



module "bigip" {
  source = "./modules/bigip"

  gcp_region           = var.gcp_region
  gcp_zone             = var.gcp_zone
  resourceOwner        = var.resourceOwner
  project_label        = var.project_name
  adminSrcAddr         = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
  REtrafficSrcAddr     = var.REtrafficSrcAddr
  vm_name              = var.vm_name
  vpc_self_link        = module.gcp-vpc.vpc_self_link
  mgmt_subnet_self_link = module.gcp-vpc.mgmt_subnet_self_link
  instance_prefix      = var.instance_prefix

  bigip-hostname     = var.bigip-hostname
  ssh_publickey      = var.ssh_publickey
  machine_type       = var.machine_type
  f5_image_name      = var.f5_image_name
  f5_image_project   = var.f5_image_project
  f5_username        = var.f5_username
  f5_username_2      = var.f5_username_2
  f5_password        = var.f5_password
  dns_suffix         = var.dns_suffix
  dns_server         = var.dns_server
  ntp_server         = var.ntp_server
  timezone           = var.timezone
  script_name        = var.script_name
  INIT_URL           = var.INIT_URL
  byol_license       = var.byol_license
}
