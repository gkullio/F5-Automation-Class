# F5 BIG-IP Single-NIC (BYOL) - GCP

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Google Cloud Platform using **Bring Your Own License (BYOL)** licensing. The BYOL all-modules image includes every BIG-IP module (LTM, ASM, AVR, APM, GTM, and more) -- which modules are provisioned depends on your registration key's entitlements and the Declarative Onboarding declaration. The single network interface carries both management and data-plane traffic, with the management GUI accessible on port 8443. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init and Declarative Onboarding (DO) -- no manual configuration required. GCP authentication uses **Application Default Credentials** (direct auth), and an Azure provider is included for cross-cloud dependencies (DNS, Key Vault, artifact store).

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
    |   License: BYOL (all modules)     |
    |   Modules: LTM, ASM, AVR, APM, GTM|
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
- GCP credentials configured via Application Default Credentials (see below)
- An SSH key pair
- An F5 BIG-IP BYOL registration key
- An Azure subscription with a Service Principal (for cross-cloud DNS, Key Vault, and artifact dependencies)

### Configure GCP Authentication

This project uses **direct GCP authentication** via Application Default Credentials -- no service account impersonation. The simplest path:

```bash
gcloud auth application-default login
```

The provider reads `gcp_project_id`, `gcp_region`, and `gcp_zone` from `terraform.tfvars`. For CI, set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to a service account key file.

### Enable the Compute Engine API

```bash
gcloud services enable compute.googleapis.com --project "<your-project>"
```

### Find the Right Image Name

GCP images are exact names, not wildcards. The default is `f5-bigip-17-1-2-1-0-0-2-byol-all-modules-2boot-loc`.

```bash
gcloud compute images list --project f5-7626-networks-public \
  --filter="name~bigip-17.*byol" --sort-by=~creationTimestamp --limit=10
```

Set `f5_image_name` in `terraform.tfvars` if you need a different version.

### Have Your Registration Key Ready

Set `byol_license` in `terraform.tfvars`. The key is activated during the Declarative Onboarding phase of first boot via the `myLicense` class. Format: `XXXXX-XXXXX-XXXXX-XXXXX-XXXXXXX`.

> **Important**: A `terraform destroy` does **not** revoke the license -- you must do that manually via the BIG-IP GUI, CLI (`SOAPLicenseClient`), or BIG-IQ if you want to re-use the key.

### Azure Service Principal

An Azure Service Principal is required for cross-cloud dependencies (DNS zone, Key Vault, artifact storage). Set `client_id`, `client_secret`, `tenant_id`, and `subscription_id` in `terraform.tfvars`.

## Project Structure

```
Single-NIC/
├── main.tf                         # Root module: public IP detection, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, GCP Console link, image, log tail
├── providers.tf                    # Provider config (google ~>6.0 direct auth, azurerm ~>4.0)
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

   Create a `terraform.tfvars` file from the variable definitions and fill in all required values (see [Variables](#variables) below). Be sure to include your `byol_license` registration key.

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
| `byol_license` | F5 BIG-IP BYOL registration key (sensitive, required) | -- |
| `bigip-hostname` | BIG-IP hostname | -- |
| `ssh_publickey` | Path to SSH public key file | -- |
| `f5_image_name` | BIG-IP BYOL image name from `f5_image_project` | `f5-bigip-17-1-2-1-0-0-2-byol-all-modules-2boot-loc` |
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
| Compute Instance (`google_compute_instance`) | F5 BIG-IP VE (BYOL all-modules, `can_ip_forward = true`) |
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
   - **Activates the BYOL license** via the `myLicense` class with the registration key
   - Sets system hostname with DNS suffix
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1; strong cipher suites)
   - Configures DNS and NTP
   - Provisions modules: LTM, ASM, AVR, APM, GTM
   - Enables UI advisory banner
   - Enables `autoPhonehome`
6. **Applies Application Services 3 (AS3)** declaration:
   - Creates a shared TLS server profile using a Let's Encrypt certificate (cert, key, and chain)

## Key Differences from PAYG Single-NIC

| Feature | PAYG Single-NIC | BYOL Single-NIC (this project) |
|---------|----------------|--------------------------------|
| Image | `f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps` | `f5-bigip-17-1-2-1-0-0-2-byol-all-modules-2boot-loc` |
| License | Marketplace billing -- no key needed | `byol_license` registration key applied via DO `myLicense` class |
| GCP auth | Service account impersonation (`terraform_sa_email`) | Direct auth (Application Default Credentials) |
| AS3 declaration | No | Yes (shared TLS server profile with Let's Encrypt cert) |
| Throughput | Baked into image (25Mbps cap) | Determined by registration key entitlements |

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
| Runtime Init | `--cloud azure` | `--cloud gcp` |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials, passwords, and your BYOL registration key.
- Management access is restricted to specific source IPs via GCP firewall rules targeted by **network tags**.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- RPM downloads use the BIG-IP instance's **dedicated service account** with `roles/storage.objectViewer` (no shared keys or signed URLs).
- The `f5_password` and `byol_license` variables are marked `sensitive` in Terraform to prevent accidental exposure in logs and plan output.
- The BYOL license is **not revoked on destroy** -- you must manually revoke it via the BIG-IP GUI, CLI, or BIG-IQ before re-using the registration key.

## Cleanup

```bash
terraform destroy
```

Or delete the resources directly from the GCP Console using the link provided in the `gcp_console_url` output.

> **Reminder**: `terraform destroy` does not revoke your BYOL license. Revoke it manually before re-using the registration key elsewhere.
