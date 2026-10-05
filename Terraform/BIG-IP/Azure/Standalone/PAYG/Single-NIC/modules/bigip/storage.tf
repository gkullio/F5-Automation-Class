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

# ---- SAS token access ------------------------------------------------------
#
# Generates a read-only SAS token for the RPM container, avoiding the need for
# Azure RBAC role assignments (which require Microsoft.Authorization/roleAssignments/write).
# time_static keeps the start/expiry deterministic across plans so custom_data
# does not trigger unwanted VM replacements.

resource "time_static" "sas_start" {}

data "azurerm_storage_account_blob_container_sas" "rpms" {
  connection_string = azurerm_storage_account.rpms.primary_connection_string
  container_name    = azurerm_storage_container.rpms.name
  https_only        = true

  start  = timeadd(time_static.sas_start.rfc3339, "-1h")
  expiry = timeadd(time_static.sas_start.rfc3339, "720h")

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}
