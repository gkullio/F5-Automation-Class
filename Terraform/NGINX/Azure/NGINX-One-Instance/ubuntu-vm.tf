# Create virtual machine
locals {
  jwt_token       = file("${path.module}/secrets/nginx-repo.jwt")
  ssl_cert        = file("${path.module}/secrets/nginx-repo.crt")
  ssl_key         = file("${path.module}/secrets/nginx-repo.key")
  api_conf        = file("${path.module}/config/api.conf")
  demoapp_conf    = file("${path.module}/config/demoapp.conf")
  dp_token        = var.dp_token
  username        = var.username
}

data "template_file" "custom_script" {
  template = file("${path.module}/nginx.tpl")
  vars = {
    jwt_token     = local.jwt_token
    ssl_cert      = local.ssl_cert
    ssl_key       = local.ssl_key
    api_conf      = local.api_conf
    demoapp_conf  = local.demoapp_conf
    dp_token      = local.dp_token
    username      = local.username
  }
}
resource "azurerm_linux_virtual_machine" "kulland_ubuntu_vm" {
  name                  = "Kulland-Ubuntu"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.management_nic.id, azurerm_network_interface.internal_nic.id]
  # network_interface_ids = [azurerm_network_interface.management_nic.id]
  size                  = var.instance_size
  custom_data = base64encode(data.template_file.custom_script.rendered)

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "${var.hostname}-${random_id.random_id.hex}"
  admin_username = var.username
  admin_password = var.password

  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}