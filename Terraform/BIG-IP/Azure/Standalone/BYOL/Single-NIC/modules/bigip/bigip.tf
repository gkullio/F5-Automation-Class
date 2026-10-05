# Create F5 BIGIP1 VM
resource "azurerm_linux_virtual_machine" "big-ip-test" {
  name                            = var.vm_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  network_interface_ids           = [azurerm_network_interface.management_nic.id]
  size                            = var.instance_size
  disable_password_authentication = var.enable_ssh_key
  computer_name                   = var.vm_name == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name
  admin_username                  = var.bigip-username
  admin_password                  = var.bigip-password
  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(coalesce(var.custom_user_data, templatefile("${path.module}/${var.script_name}.tmpl",
    {
      INIT_URL             = var.INIT_URL
      DO_VER               = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER              = format("v%s", split("-", var.as3_rpm_file)[2])
      rpm_storage_account  = azurerm_storage_account.rpms.name
      rpm_container        = azurerm_storage_container.rpms.name
      rpm_sas_token        = data.azurerm_storage_account_blob_container_sas.rpms.sas
      do_rpm_key           = azurerm_storage_blob.do_rpm.name
      as3_rpm_key          = azurerm_storage_blob.as3_rpm.name
      bigip_username       = var.f5_username
      bigip_username_2     = var.f5_username_2
      ssh_keypair          = var.ssh_publickey
      bigip_password       = var.f5_password
      dns_server           = var.dns_server
      dns_suffix           = var.dns_suffix
      ntp_server           = var.ntp_server
      timezone             = var.timezone
      license_key          = var.license_key
  })))
  source_image_reference {
    offer     = var.f5_product_name
    publisher = var.image_publisher
    sku       = var.f5_image_name
    version   = var.f5_version
  }

  os_disk {
    caching                   = "ReadWrite"
    disk_size_gb              = 100
    name                      = "${var.instance_prefix}-osdisk-f5vm01"
    storage_account_type      = var.storage_account_type
    write_accelerator_enabled = false
  }

  admin_ssh_key {
    public_key = file(var.ssh_publickey)
    username   = var.bigip-username
  }
  plan {
    name      = var.f5_image_name
    product   = var.f5_product_name
    publisher = var.image_publisher
  }
  zone = var.availability_zone

  tags = {
    owner = var.resourceOwner
  }

#  depends_on = [azurerm_network_interface_security_group_association.mgmt_security, azurerm_network_interface_security_group_association.internal_security, azurerm_network_interface_security_group_association.external_security, azurerm_network_interface_security_group_association.external_public_security]
}