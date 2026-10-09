##################### Collect Public IP address #####################

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "azurerm_resource_group" "rg" {
    name                 = var.rg_name
    location             = var.location
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


module "azure-vnet" {
    source              = "./modules/azure-vnet"
    resource_group_name = azurerm_resource_group.rg.name
    location            = var.location
    vnet_name           = var.vnet_name
    vnet_address_space  = var.vnet_address_space
    mgmt_subnet_name    = var.mgmt_subnet_name
    mgmt_address_space  = var.mgmt_address_space
}


module "bigip" {
    source              = "./modules/bigip"
    resource_group_name = azurerm_resource_group.rg.name
    location            = var.location
    resourceOwner       = var.resourceOwner
    adminSrcAddr        = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
    REtrafficSrcAddr    = var.REtrafficSrcAddr
    vm_name             = var.vm_name
    mgmt_subnet_id      = module.azure-vnet.mgmt_subnet_id
    instance_prefix     = var.instance_prefix

    # BIG-IP VE variables
    bigip-hostname      = var.bigip-hostname
    bigip-username      = var.bigip-username
    bigip-password      = var.bigip-password
    ssh_publickey       = var.ssh_publickey
    instance_size       = var.instance_size
    f5_product_name     = var.f5_product_name
    f5_image_name       = var.f5_image_name
    f5_version          = var.f5_version
    f5_username         = var.f5_username
    f5_username_2       = var.f5_username_2
    f5_password         = var.f5_password
    dns_suffix          = var.dns_suffix
    dns_server          = var.dns_server
    availability_zone   = var.availability_zone
    ntp_server          = var.ntp_server
    timezone            = var.timezone
    script_name         = var.script_name
    enable_ssh_key      = var.enable_ssh_key 
    INIT_URL            = var.INIT_URL
}