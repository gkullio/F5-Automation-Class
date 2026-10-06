# F5 BIG-IP Single-NIC (PAYG) - GCP

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Google Cloud Platform using **Pay-As-You-Go (PAYG)** licensing (Best Plus 25Mbps). The single network interface carries both management and data-plane traffic, with the management GUI accessible on port 8443. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init and Declarative Onboarding (DO) -- no manual configuration required. GCP authentication uses **service account impersonation**, and an Azure provider is included for cross-cloud dependencies (DNS, Key Vault, artifact store).

## Architecture

```
                      Internet
                         |
                         v
              [ Static External IP ]
              (google_compute_address)
                         |
                         v
            [ VPC Firewall Rules ]
            Admin: 22, 8443 + ICMP
            (allowlisted IPs only)
            App:   80, 443, 8080, 8081
            Targeted by network tag
                         |
                         v
    +------------------------------------+
    |        BIG-IP VE (Single NIC)      |
    |   Management Subnet (var.mgmt_cidr)|
    |   can_ip_forward = true            |
    |                                    |
    |   Modules: LTM, ASM, AVR, APM, GTM|
    |            (Best tier)             |
    +------------------------------------+
          |
          v
    [ GCS Bucket ]
    DO + AS3 RPMs
    (service account w/ objectViewer)

    GCP VPC Network (custom mode)
```

### Traffic Flow

1. External clients connect to the BIG-IP's static external IP on the desired service port
2. GCP firewall rules filter inbound traffic by source IP and port, targeted via **network tags** (not per-NIC security groups)
3. The single NIC carries both management (port 8443) and data-plane traffic
4. `can_ip_forward = true` is set on the instance, allowing it to forward packets with addresses that are not its own (the GCP equivalent of AWS `source_dest_check = false`)

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud` CLI)
- A GCP project with the **Compute Engine API** enabled
- GCP credentials configured for service account impersonation (see below)
- An SSH key pair
- An Azure subscription with a Service Principal (for cross-cloud DNS, Key Vault, and artifact dependencies)

### Configure GCP Service Account Impersonation

This project authenticates to GCP by impersonating a dedicated service account. Your user (or CI runner) needs `roles/iam.serviceAccountTokenCreator` on the target service account, and that service account needs permissions to manage Compute, Storage, and IAM resources. This keeps the Terraform SA's credentials off disk -- your local ADC mints a short-lived token (20 minutes) for the dedicated service account.

1. **Create a Terraform service account**:

   ```bash
   gcloud iam service-accounts create terraform \
     --display-name "Terraform Automation SA" \
     --project "<your-project>"
   ```

2. **Grant the service account Editor (or a custom role)**:

   ```bash
   gcloud projects add-iam-policy-binding <your-project> \
     --member "serviceAccount:terraform@<your-project>.iam.gserviceaccount.com" \
     --role "roles/editor"
   ```

3. **Grant your user Token Creator on the service account**:

   ```bash
   gcloud iam service-accounts add-iam-policy-binding \
     terraform@<your-project>.iam.gserviceaccount.com \
     --member "user:<your-email>" \
     --role "roles/iam.serviceAccountTokenCreator" \
     --project "<your-project>"
   ```

4. **Authenticate your local session**:

   ```bash
   gcloud auth application-default login
   ```

5. **Set `terraform_sa_email`** in your `terraform.tfvars`:

   ```hcl
   terraform_sa_email = "terraform@<your-project>.iam.gserviceaccount.com"
   ```

The provider block in `providers.tf` handles the rest: an aliased `google.impersonation` provider fetches a 20-minute access token, and the primary `google` provider uses that token for all API calls.

### Find the Right Image Name

GCP images are exact names, not wildcards. The default is `f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps`.

```bash
gcloud compute images list --project f5-7626-networks-public \
  --filter="name~bigip-17.*payg" --sort-by=~creationTimestamp --limit=10
```

Set `f5_image_name` in `terraform.tfvars` if you need a different version.

### Azure Service Principal

An Azure Service Principal is required for cross-cloud dependencies (DNS zone, Key Vault, artifact storage). Set `client_id`, `client_secret`, `tenant_id`, and `subscription_id` in `terraform.tfvars`.

## Project Structure

```
Single-NIC/
├── main.tf                         # Root module: public IP detection, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, GCP Console link, image, log tail
├── providers.tf                    # Provider config (google ~>6.0 w/ impersonation, azurerm ~>4.0)
├── terraform.tfvars                # Variable values (do not commit)
└── modules/
    ├── gcp-vpc/
    │   ├── main.tf                 # VPC network + management subnet
    │   ├── variables.tf
    │   └── outputs.tf
    └── bigip/
        ├── bigip.tf                # BIG-IP Compute Engine instance
        ├── network.tf              # Image lookup, firewall rules, static external IP
        ├── gcs.tf                  # GCS bucket, RPM objects, service account + IAM
        ├── variables.tf
        ├── bigip_outputs.tf
        ├── f5_onboard.tmpl         # Startup script template (cloud-init onboarding)
        └── rpm_files/
            ├── f5-declarative-onboarding-*.noarch.rpm
            └── f5-appsvcs-*.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   Create a `terraform.tfvars` file from the variable definitions and fill in all required values (see [Variables](#variables) below).

2. **Deploy with Terraform**

   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```

3. **Access the BIG-IP**

   After deployment, Terraform outputs:
   - **SSH**: `ssh admin@<public_ip>`
   - **WebUI**: `https://<public_ip>:8443`
   - **GCP Console**: Direct link to the Compute Engine instance detail page
   - **Onboarding log**: SSH command to tail the startup script log
   - **Serial console**: `gcloud` command to view serial port output

## Variables

### GCP Targeting

| Variable | Description | Default |
|----------|-------------|---------|
| `gcp_project_id` | GCP project ID to deploy into | -- |
| `gcp_region` | GCP region (e.g. `us-east1`) | -- |
| `gcp_zone` | GCP zone (e.g. `us-east1-b`) | -- |
| `terraform_sa_email` | Service account email to impersonate for GCP auth | -- |

### Azure Credentials

| Variable | Description | Required |
|----------|-------------|----------|
| `client_id` | Azure Service Principal Application ID | Yes |
| `client_secret` | Azure Service Principal Secret | Yes |
| `tenant_id` | Azure AD Tenant ID | Yes |
| `subscription_id` | Azure Subscription ID | Yes |

### Global

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Grouping label stamped onto every resource | `bigip-gcp-1nic` |
| `resourceOwner` | Owner name for labeling and audit | -- |
| `machine_type` | GCP machine type ([sizing guide](https://clouddocs.f5.com/cloud/public/v1/matrix.html#google-cloud-platform)) | `n2-standard-8` |

### Networking

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_name` | VPC network name | -- |
| `mgmt_subnet_name` | Management subnet name | -- |
| `mgmt_cidr` | Management subnet CIDR | -- |

### Access Control

| Variable | Description | Default |
|----------|-------------|---------|
| `vpnMgmtSrcAddr` | List of IPs/CIDRs allowed management access (SSH, WebUI) | -- |
| `REtrafficSrcAddr` | List of IPs/CIDRs for application traffic sources | -- |

> **Note**: The deployer's current public IP is automatically detected and added to the management allowlist.

### BIG-IP VM

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | Compute Engine instance name | -- |
| `instance_prefix` | Prefix for derived resource names (firewall rules, SA, bucket) | -- |

### BIG-IP Onboarding

| Variable | Description | Default |
|----------|-------------|---------|
| `bigip-hostname` | BIG-IP hostname | -- |
| `ssh_publickey` | Path to SSH public key file | -- |
| `f5_image_name` | BIG-IP image name from `f5_image_project` | `f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps` |
| `f5_image_project` | GCP project containing F5 BIG-IP images | `f5-7626-networks-public` |
| `f5_username` | First BIG-IP admin user | -- |
| `f5_username_2` | Second BIG-IP admin user | -- |
| `f5_password` | Password for both BIG-IP users (sensitive) | -- |
| `dns_suffix` | DNS suffix for BIG-IP hostname | -- |
| `dns_server` | Primary DNS server | -- |
| `ntp_server` | Primary NTP server | -- |
| `timezone` | System timezone | `UTC` |
| `script_name` | Startup script template name (without `.tmpl`) | `f5_onboard` |
| `INIT_URL` | F5 BIG-IP Runtime Init download URL | v2.0.3 |

## Outputs

| Output | Description |
|--------|-------------|
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<public_ip>` |
| `BIG-IP-UI-ip` | BIG-IP management URL: `https://<public_ip>:8443` |
| `gcp_console_url` | Direct link to the GCP Console instance detail page |
| `bigip_image` | Name of the BIG-IP image used for deployment |
| `onboarding_log_tail` | SSH command to tail the startup script log in real time |
| `serial_console_cmd` | `gcloud` command to view serial port output for troubleshooting |

## GCP Resources Created

| Resource | Purpose |
|----------|---------|
| VPC Network (`google_compute_network`) | Custom-mode network backbone |
| Subnet (`google_compute_subnetwork`) | Single subnet for all BIG-IP traffic |
| Static External IP (`google_compute_address`) | Reserved public IP for management and data access |
| Firewall Rule -- mgmt (`google_compute_firewall`) | Inbound rules for ports 22, 8443 + ICMP (admin sources only) |
| Firewall Rule -- app (`google_compute_firewall`) | Inbound rules for ports 80, 443, 8080, 8081 (app traffic sources) |
| Compute Instance (`google_compute_instance`) | F5 BIG-IP VE (PAYG Best Plus 25Mbps, `can_ip_forward = true`) |
| GCS Bucket (`google_storage_bucket`) | Hosts DO and AS3 extension RPMs |
| Bucket Objects x2 (`google_storage_bucket_object`) | Declarative Onboarding and AS3 RPM files |
| Service Account (`google_service_account`) | Dedicated SA attached to the BIG-IP instance |
| Bucket IAM Member (`google_storage_bucket_iam_member`) | Grants the BIG-IP SA `roles/storage.objectViewer` on the RPM bucket |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` startup script:

1. **Sets passwords** for root and admin accounts
2. **Tunes system database variables** (`provision.extramb`, `restjavad.extramb`, timeouts) for reliable extension installation
3. **Downloads F5 extensions** (DO and AS3 RPMs) from the GCS bucket using an OAuth2 access token obtained from the GCP metadata server via a Python helper script (`gcs_download.py`) -- no `gcloud` CLI required
4. **Installs F5 BIG-IP Runtime Init**
5. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname with DNS suffix
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1; strong cipher suites)
   - Configures DNS and NTP
   - Provisions all Best-tier modules: LTM, ASM, AVR, APM, GTM
   - Enables UI advisory banner
   - Enables `autoPhonehome`

## Key Differences from Azure Single-NIC

| Feature | Azure Single-NIC | GCP Single-NIC (this project) |
|---------|-----------------|-------------------------------|
| Network firewall | Network Security Group (per NIC) | VPC Firewall Rules (per VPC, targeted by network tag) |
| Static IP | Azure Public IP (Standard SKU) | `google_compute_address` (static external) |
| IP forwarding | `source_dest_check = false` on NIC | `can_ip_forward = true` on instance (all NICs) |
| SSH keys | Azure VM admin user | Instance metadata `ssh-keys` |
| Boot image | Azure Marketplace (publisher/offer/SKU) | GCP Image (global, from `f5-7626-networks-public`) |
| User data | `custom_data` (base64 cloud-init) | `metadata_startup_script` |
| RPM delivery | Azure Blob Storage + managed identity | GCS bucket + service account with `roles/storage.objectViewer` |
| Auth pattern | Service Principal (client_id/secret) | Service account impersonation (short-lived token) |
| Runtime Init | `--cloud azure` | `--cloud gcp` |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials and passwords.
- Management access is restricted to specific source IPs via GCP firewall rules targeted by **network tags**.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- RPM downloads use the BIG-IP instance's **dedicated service account** with `roles/storage.objectViewer` (no shared keys or signed URLs).
- GCP authentication uses **service account impersonation** -- your user never holds long-lived service account keys. The impersonation token lifetime is 20 minutes (configurable up to 3600s).
- The `f5_password` variable is marked `sensitive` in Terraform to prevent accidental exposure in logs and plan output.
- PAYG throughput is baked into the image -- a 25Mbps image caps at 25Mbps regardless of machine type.

## Cleanup

```bash
terraform destroy
```

Or delete the resources directly from the GCP Console using the link provided in the `gcp_console_url` output.
