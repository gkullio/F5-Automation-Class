variable "gcp_region" {
  type        = string
  description = "GCP region (e.g. us-central1)."
}
variable "gcp_zone" {
  type        = string
  description = "GCP zone (e.g. us-central1-a)."
}
variable "gcp_project_id" {
  type        = string
  description = "Google Cloud Project ID from the main Console"
}
variable "gcp_credentials_file" {
  type        = string
  description = "Path to GCP service account JSON key file. Leave null to use Application Default Credentials (gcloud auth application-default login)."
  default     = null
}
variable "mgmt_subnet_cidr" {
  type        = string
  description = "The CIDR block for the management subnet."
}
variable "int_subnet_cidr" {
  type        = string
  description = "The CIDR block for the internal subnet."
}
variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
}
variable "adminSrcAddr" {
  type        = list(string)
  description = "Allowed Admin source IP prefixes in CIDR notation (e.g. [\"203.0.113.10/32\"])"
}
variable "hostname" {
  type        = string
  description = "Hostname of the ubuntu VM"
}
variable "machine_type" {
  type        = string
  description = "The GCE machine type (e.g. e2-medium)."
}
variable "resourceOwner" {
  type        = string
  description = "The owner of the resources (used in labels)."
}
variable "dp_token" {
  type        = string
  description = "The NGINX Data Plane token."
}


variable terraform_sa_email {
  type        = string
}