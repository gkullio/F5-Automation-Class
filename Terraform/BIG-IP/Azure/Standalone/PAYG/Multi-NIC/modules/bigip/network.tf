##################### Management NIC #####################

resource "azurerm_public_ip" "management_pubip" {
  name                = "bigip-management-pubip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "management_nsg" {
  name                = "bigip-mgmt-NSG"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH-WebUI"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "443", "8443"]
    source_address_prefixes    = var.adminSrcAddr
    destination_address_prefix = "*"
  }
  tags = {
    owner = var.resourceOwner
  }
}

resource "azurerm_network_interface" "management_nic" {
  name                = "bigip-management-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "bigip-management-nic-configuration"
    subnet_id                     = var.mgmt_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management_pubip.id
  }
}

resource "azurerm_network_interface_security_group_association" "mgmt" {
  network_interface_id      = azurerm_network_interface.management_nic.id
  network_security_group_id = azurerm_network_security_group.management_nsg.id
}

##################### External NIC #####################

resource "azurerm_public_ip" "external_pubip" {
  name                = "bigip-external-pubip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "external_nsg" {
  name                = "bigip-ext-NSG"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-HTTP-HTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080", "8081", "8443"]
    source_address_prefixes    = concat(var.adminSrcAddr, var.REtrafficSrcAddr)
    destination_address_prefix = "*"
  }
  tags = {
    owner = var.resourceOwner
  }
}

resource "azurerm_network_interface" "external_nic" {
  name                = "bigip-external-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "bigip-external-nic-configuration"
    subnet_id                     = var.ext_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.external_pubip.id
  }
}

resource "azurerm_network_interface_security_group_association" "ext" {
  network_interface_id      = azurerm_network_interface.external_nic.id
  network_security_group_id = azurerm_network_security_group.external_nsg.id
}

##################### Internal NIC #####################

resource "azurerm_network_security_group" "internal_nsg" {
  name                = "bigip-int-NSG"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-All-Internal"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  tags = {
    owner = var.resourceOwner
  }
}

resource "azurerm_network_interface" "internal_nic" {
  name                = "bigip-internal-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "bigip-internal-nic-configuration"
    subnet_id                     = var.int_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "int" {
  network_interface_id      = azurerm_network_interface.internal_nic.id
  network_security_group_id = azurerm_network_security_group.internal_nsg.id
}
