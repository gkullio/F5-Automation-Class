resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vnet_name}-${random_id.random_id.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "management" {
  name                 = "${var.mgmt_subnet_name}-${random_id.random_id.hex}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.mgmt_address_space]
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.int_subnet_name}-${random_id.random_id.hex}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.int_address_space]
}



# Create management public IP
resource "azurerm_public_ip" "management_pubip" {
  name                = "ubuntu-management_pubip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create internal public IP
resource "azurerm_public_ip" "internal_pubip" {
  name                = "ubuntu-internal_pubip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "management_nsg" {
  name                = "Kulland-mgmt-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "443", "80", "8080", "8443"]
    source_address_prefixes    = var.adminSrcAddr
    destination_address_prefix = "*"
  }
  tags = {
    owner = var.resourceOwner
  }  
}

resource "azurerm_network_security_group" "internal_nsg" {
  name                = "Kulland-internal-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Application-Access"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80", "8080", "8443"]
    source_address_prefixes    = var.adminSrcAddr
    destination_address_prefix = "*"
  }
  tags = {
    owner = var.resourceOwner
  }
}  

# Create network interface
resource "azurerm_network_interface" "management_nic" {
  name                = "management-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "managenment_nic_configuration"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management_pubip.id
  }
}

resource "azurerm_network_interface" "internal_nic" {
  name                = "internal-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal_nic_configuration"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.99"
    public_ip_address_id          = azurerm_public_ip.internal_pubip.id
    primary                       = true
  }
  ip_configuration {
    name                          = "application_public_private_ip_1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.100"
  }
  ip_configuration {
    name                          = "application_public_private_ip_2"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.101"
  }
  ip_configuration {
    name                          = "application_public_private_ip_3"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.102"
  }
  ip_configuration {
    name                          = "application_public_private_ip_4"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.103"
  }
  ip_configuration {
    name                          = "application_public_private_ip_5"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.104"
  }
  ip_configuration {
    name                          = "application_public_private_ip_6"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.245.2.105"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "mgmt" {
  network_interface_id      = azurerm_network_interface.management_nic.id
  network_security_group_id = azurerm_network_security_group.management_nsg.id
}

resource "azurerm_network_interface_security_group_association" "internal" {
  network_interface_id      = azurerm_network_interface.internal_nic.id
  network_security_group_id = azurerm_network_security_group.internal_nsg.id
}