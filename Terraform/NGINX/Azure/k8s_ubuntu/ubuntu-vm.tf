# Create virtual machine
data "template_file" "custom_script" {
  template = file("${path.module}/k8s.tpl")
}
resource "azurerm_linux_virtual_machine" "kulland_ubuntu_vm" {
  name                  = "kulland-k8s-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.management_nic.id, azurerm_network_interface.internal_nic.id]
  size                  = var.instance_size
  #custom_data           = filebase64("${path.module}/nginx.tpl")
  custom_data = base64encode(data.template_file.custom_script.rendered)

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "server"
    version   = "latest"
  }

  computer_name  = var.hostname
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