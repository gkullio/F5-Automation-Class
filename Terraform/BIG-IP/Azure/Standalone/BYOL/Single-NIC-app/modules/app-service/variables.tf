variable "app_name" {
  description = "Name of the Linux Web App (must be globally unique across Azure)"
  type        = string
}
variable "resource_group_name" {
  description = "Name of the existing Resource Group"
  type        = string
}
variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}
variable "create_service_plan" {
  description = "Set to true to create a new App Service Plan, or false to use an existing one"
  type        = bool
  default     = true
}
variable "existing_service_plan_id" {
  description = "ID of an existing App Service Plan (required if create_service_plan is false)"
  type        = string
  default     = null
}
variable "service_plan_name" {
  description = "Name of the App Service Plan if created (defaults to app_name-asp)"
  type        = string
  default     = null
}
variable "sku_name" {
  description = "SKU for the App Service Plan (e.g., B1, P1v2, P1v3)"
  type        = string
  default     = "B1"
}
variable "docker_image" {
  description = "Docker image repository and tag (e.g., stockdemo/demoapp:latest)"
  type        = string
  default     = "stockdemo/demoapp:latest"
}
variable "docker_registry_url" {
  description = "URL of the container registry (e.g., https://index.docker.io for Docker Hub)"
  type        = string
  default     = "https://index.docker.io"
}
variable "app_port" {
  description = "Port the application inside the container listens on (mapped to external HTTP port 80 via WEBSITES_PORT)"
  type        = number
  default     = 8080
}
variable "always_on" {
  description = "Keep the App Service loaded even when idle. Note: Not supported on Free/Shared tiers (requires B1 or higher)"
  type        = bool
  default     = true
}
variable "https_only" {
  description = "Enforce HTTPS traffic"
  type        = bool
  default     = true
}
variable "extra_app_settings" {
  description = "Additional key-value pairs for App Settings"
  type        = map(string)
  default     = {}
}
variable "tags" {
  description = "Tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "enable_private_endpoint" {
  description = "Set to true to create a private endpoint, DNS zone, and VNet link for the App Service"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for the private endpoint (required when enable_private_endpoint is true)"
  type        = string
  default     = null
}

variable "vnet_id" {
  description = "VNet ID for the private DNS zone virtual network link (required when enable_private_endpoint is true)"
  type        = string
  default     = null
}