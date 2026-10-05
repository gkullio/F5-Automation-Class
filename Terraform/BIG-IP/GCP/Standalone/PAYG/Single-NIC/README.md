# BIG-IP on GCP - Single-NIC

Deploys a single BIG-IP VE on GCP with one network interface (management and
data plane share eth0), mirroring the AWS Single-NIC project.

## GCP vs AWS key differences

| Concept           | AWS                          | GCP                                      |
|-------------------|------------------------------|------------------------------------------|
| Network           | VPC (regional)               | VPC Network (global)                     |
| Firewall          | Security Group (per ENI)     | Firewall Rule (per VPC, targeted by tag) |
| Static IP         | Elastic IP                   | `google_compute_address`                 |
| source_dest_check | Per ENI attribute            | `can_ip_forward` on instance (all NICs)  |
| SSH key           | `aws_key_pair`               | Instance metadata `ssh-keys`             |
| Boot image        | AMI (per region)             | Image (global, from project)             |
| User data         | `user_data_base64`           | `metadata_startup_script`                |
| runtime-init      | `--cloud aws`                | `--cloud gcp`                            |

## Before your first apply

1. **Enable the Compute Engine API** in your GCP project.
2. **Find the right image name:**
   ```
   gcloud compute images list --project f5-7626-networks-public \
     --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
   ```
3. **Set credentials** - `gcloud auth application-default login` for local
   runs, plus Azure SP for Key Vault and DNS.
4. Run `terraform init` then `terraform plan`.


## Gotchas

- **GUI on 8443.** Single-NIC means httpd cedes 443 to TMM, same as AWS.
- **can_ip_forward** applies to all interfaces (GCP has no per-NIC control).
- **No egress firewall rule needed.** GCP VPCs allow all egress by default.
- **Image names are exact.** GCP does not support wildcard AMI lookups; you
  must specify the full image name (or use a family if F5 publishes one).
- **Startup script changes rebuild the instance** - GCP replaces the instance
  when `metadata_startup_script` changes.


gcloud services enable iamcredentials.googleapis.com --project="f5-gcs-4261-sales-na-ent"

gcloud iam service-accounts create terraform \
  --display-name="Terraform Automation SA" \
  --project="f5-gcs-4261-sales-na-ent"

terraform@f5-gcs-4261-sales-na-ent.iam.gserviceaccount.com

# Example: Assign Editor (or more granular roles) to the Service Account
gcloud projects add-iam-policy-binding f5-gcs-4261-sales-na-ent \
  --member="serviceAccount:terraform@f5-gcs-4261-sales-na-ent.iam.gserviceaccount.com" \
  --role="roles/editor"

# Add to variables
variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "terraform_sa_email" {
  type        = string
  description = "Service account email to impersonate"
}

# Modify providers.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# 1. Alias provider using your local ADC credentials
provider "google" {
  alias = "impersonation"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# 2. Generate short-lived token using the impersonation provider
data "google_service_account_access_token" "default" {
  provider               = google.impersonation
  target_service_account = var.terraform_sa_email
  scopes                 = ["userinfo-email", "cloud-platform"]
  lifetime               = "1200s" # 20 minutes (max: 3600s / 1 hour)
}

# 3. Default provider that Terraform resources will use
provider "google" {
  project      = var.project_id
  region       = var.region
  access_token = data.google_service_account_access_token.default.access_token
}

# tfvars
project_id         = "my-gcp-project-123"
terraform_sa_email = "terraform@my-gcp-project-123.iam.gserviceaccount.com"

# How to use

gcloud auth application-default login


gcloud iam service-accounts add-iam-policy-binding \
  terraform@f5-gcs-4261-sales-na-ent.iam.gserviceaccount.com \
  --member="user:g.kulland@f5.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="f5-gcs-4261-sales-na-ent"

----
Updated IAM policy for serviceAccount [terraform@f5-gcs-4261-sales-na-ent.iam.gserviceaccount.com].
bindings:
- members:
  - user:g.kulland@f5.com
  role: roles/iam.serviceAccountTokenCreator
etag: BwZcFkgWawk=
version: 1
----

