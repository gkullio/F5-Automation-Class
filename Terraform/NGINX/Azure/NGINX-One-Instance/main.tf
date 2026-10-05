resource "azurerm_resource_group" "rg" {
  location   = var.resource_group_location
  name       = "${var.resource_group_name_prefix}-${random_id.random_id.hex}"
  depends_on = [terraform_data.jwt_validation]
}


# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  byte_length = 1
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS" 
  public_network_access_enabled = false
  allow_nested_items_to_be_public = false
}