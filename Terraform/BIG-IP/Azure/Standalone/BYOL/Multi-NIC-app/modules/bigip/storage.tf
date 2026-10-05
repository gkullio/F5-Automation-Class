# ---------------------------------------------------------------------------
# Azure Blob Storage for F5 extension RPMs + Managed Identity access
#
# The DO and AS3 RPMs checked into rpm_files/ are uploaded here at apply
# time.  The BIG-IP downloads them at first boot via its system-assigned
# managed identity (see blob_download.py in f5_onboard.tmpl) before
# runtime-init runs, so the extensions install from local file:// paths
# with no external network dependency beyond the storage account.
# ---------------------------------------------------------------------------

locals {
  rpm_container_name = "bigip-rpms"
  do_rpm_path        = "${path.module}/rpm_files/${var.do_rpm_file}"
  as3_rpm_path       = "${path.module}/rpm_files/${var.as3_rpm_file}"
}

# ---- Storage account -------------------------------------------------------

resource "azurerm_storage_account" "rpms" {
  name                            = "rpms${random_id.random_id.hex}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = { owner = var.resourceOwner }
}

# ---- Blob container --------------------------------------------------------

resource "azurerm_storage_container" "rpms" {
  name               = local.rpm_container_name
  storage_account_id = azurerm_storage_account.rpms.id
}

# ---- RPM blobs -------------------------------------------------------------

resource "azurerm_storage_blob" "do_rpm" {
  name                 = var.do_rpm_file
  storage_container_id = azurerm_storage_container.rpms.id
  type                 = "Block"
  source               = local.do_rpm_path
}

resource "azurerm_storage_blob" "as3_rpm" {
  name                 = var.as3_rpm_file
  storage_container_id = azurerm_storage_container.rpms.id
  type                 = "Block"
  source               = local.as3_rpm_path
}

# ---- Managed Identity access -----------------------------------------------
#
# Grants the BIG-IP VM's system-assigned managed identity read access to the
# RPM blobs.  The role assignment depends on the VM (for its principal_id),
# so there is a brief window at first boot before the assignment propagates
# through Azure AD -- the retry loop in f5_onboard.tmpl handles this.

resource "azurerm_role_assignment" "bigip_blob_reader" {
  scope                = azurerm_storage_account.rpms.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.big-ip-test.identity[0].principal_id
}
