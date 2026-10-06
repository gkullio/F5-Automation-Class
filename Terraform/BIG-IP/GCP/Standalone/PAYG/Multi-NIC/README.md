# F5 BIG-IP Multi-NIC (PAYG) - GCP

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **3-NIC topology** on Google Cloud Platform using **Pay-As-You-Go (PAYG)** licensing (Best Plus 25Mbps tier). Unlike AWS or Azure, GCP requires each network interface on an instance to reside in a **separate VPC network**, so this project creates **three VPC networks** -- one each for management, external, and internal traffic. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init, Declarative Onboarding (DO), and Application Services 3 (AS3) -- no manual configuration required. GCP authentication uses **service account impersonation** for least-privilege access.

## Architecture

```
                      Internet
                         |
            +------------+------------+
            |                         |
            v                         v
  [ Mgmt External IP ]      [ External External IP ]
  (Static, Regional)         (Static, Regional)
            |                         |
            v                         v
  [ mgmt-fw ]               [ external-fw ]
  Ports: 22, 443, ICMP      Ports: 80, 443,
  Source: allowlisted IPs           8080, 8081
                             Source: RE traffic IPs
            |                         |
            v                         v
+-----------+-----+   +--------------+-----+   +---------------------+
| Management VPC  |   |  External VPC      |   |  Internal VPC       |
|                 |   |                    |   |                     |
| mgmt subnet    |   | external subnet   |   | internal subnet     |
|                 |   |                    |   |                     |
+---------+-------+   +--------+-----------+   +---------+-----------+
          |                    |                         |
          v                    v                         v
   +------+--------------------+-------------------------+------+
   |                    BIG-IP VE (3-NIC)                       |
   |                                                            |
   |  nic0 (mgmt)     nic1 (external/1.1)  nic2 (internal/1.2) |
   |  TMUI on :443    Virtual servers       Backend traffic     |
   |  SSH on :22      Public VIP            No external IP      |
   |                                                            |
   |  Module: LTM + ASM + AVR + APM + GTM (Best Plus tier)     |
   |                                                            |
   |  DO: VLANs, Self-IPs, TMM default route via external_gw   |
   +------------------------------------------------------------+
                             |
                             v
                   [ internal-fw ]
                   Protocol: all
                   Source: 10.0.0.0/8
```

### Key GCP Constraint

GCP enforces a **one-NIC-per-VPC** rule: each network interface on a compute instance must belong to a different VPC network. This is the fundamental structural difference from AWS (where all ENIs share one VPC with different subnets) and Azure (where all NICs share one VNet with different subnets). The `gcp-vpc` module creates all three VPC networks and their subnets in a single call.

### Traffic Flow

1. **Management**: Admin connects to the management external IP on **port 443** (TMUI) or **port 22** (SSH) through the mgmt VPC firewall
2. **External (data-plane)**: Client traffic arrives at the external external IP on ports **80/443/8080/8081**, passes through the external VPC firewall to virtual servers on nic1 (BIG-IP interface 1.1)
3. **Internal (server-side)**: BIG-IP forwards traffic to backend servers via nic2 (BIG-IP interface 1.2) in the internal VPC; all RFC1918 traffic is permitted

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated
- Compute Engine API enabled in the target GCP project
- A GCP service account with permissions to create VPCs, firewall rules, compute instances, GCS buckets, and IAM bindings
- Service account impersonation configured (see [Authentication](#authentication) below)
- An SSH key pair (path provided via `ssh_publickey`)
- Azure credentials (for cross-cloud dependencies such as Key Vault, DNS, or artifact store)

### Machine Type NIC Limits

GCP limits the number of network interfaces based on the machine type's vCPU count. A 3-NIC deployment requires **8 or more vCPUs**:

| vCPUs | Max NICs | Example Machine Types |
|-------|----------|-----------------------|
| 2     | 2        | n2-standard-2, e2-standard-2 |
| 4     | 4        | n2-standard-4, e2-standard-4 |
| **8** | **8**    | **n2-standard-8** (default), e2-standard-8 |
| 16+   | 8        | n2-standard-16, n2-standard-32 |

> **Note**: The default machine type `n2-standard-8` supports up to 8 NICs, well above the 3 required.

### Authentication

This project uses **service account impersonation**. Your user or CI identity impersonates a dedicated Terraform service account (`terraform_sa_email`) that holds the project-level permissions. This avoids exporting long-lived service account keys.

1. Create a service account for Terraform:

   ```bash
   gcloud iam service-accounts create terraform-deploy \
     --display-name="Terraform deploy SA"
   ```

2. Grant the necessary roles (Compute Admin, Storage Admin, Service Account User, etc.):

   ```bash
   gcloud projects add-iam-policy-binding <PROJECT_ID> \
     --member="serviceAccount:terraform-deploy@<PROJECT_ID>.iam.gserviceaccount.com" \
     --role="roles/editor"
   ```

3. Grant your user permission to impersonate it:

   ```bash
   gcloud iam service-accounts add-iam-policy-binding \
     terraform-deploy@<PROJECT_ID>.iam.gserviceaccount.com \
     --member="user:<YOUR_EMAIL>" \
     --role="roles/iam.serviceAccountTokenCreator"
   ```

4. Set `terraform_sa_email` in `terraform.tfvars` to the service account email.

## Project Structure

```
Multi-NIC/
├── main.tf                         # Root module: public IP lookup, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, VIP, console links, per-NIC IPs
├── providers.tf                    # Google provider with SA impersonation
├── terraform.tfvars                # Variable values (do not commit)
└── modules/
    ├── gcp-vpc/
    │   ├── main.tf                 # 3 VPC networks + 3 subnets (mgmt, ext, int)
    │   ├── variables.tf            # VPC/subnet names and CIDRs
    │   └── outputs.tf              # VPC and subnet self-links
    └── bigip/
        ├── bigip.tf                # BIG-IP compute instance (3 NICs)
        ├── network.tf              # Image lookup, 3 firewall rules, 2 external IPs, 2 internal IPs
        ├── gcs.tf                  # GCS bucket, RPM objects, service account + IAM
        ├── variables.tf            # All bigip module variables
        ├── bigip_outputs.tf        # Per-NIC IPs, instance name/ID, image name
        ├── f5_onboard.tmpl         # Startup script template (DO + AS3)
        └── rpm_files/
            ├── f5-declarative-onboarding-1.49.0-14.noarch.rpm
            └── f5-appsvcs-3.57.0-13.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   ```bash
   cp terraform.tfvars terraform.tfvars.backup   # if a tfvars already exists
   ```

   Edit `terraform.tfvars` and fill in all required values (see [Variables](#variables) below).

2. **Deploy with Terraform**

   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```

3. **Access the BIG-IP**

   After deployment, Terraform outputs:
   - **SSH**: `ssh admin@<mgmt_public_ip>`
   - **WebUI**: `https://<mgmt_public_ip>` (port 443 on the dedicated management NIC)
   - **External VIP**: `https://<external_public_ip>` (virtual server traffic)
   - **GCP Console**: Direct link to the instance detail page
   - **Onboarding log**: SSH command to tail the startup script log
   - **Serial console**: `gcloud` command to view serial port output

## Variables

### GCP Targeting

| Variable | Description | Default |
|----------|-------------|---------|
| `gcp_project_id` | GCP project ID to deploy into | -- |
| `gcp_region` | GCP region (e.g. `us-east1`) | -- |
| `gcp_zone` | GCP zone (e.g. `us-east1-b`) | -- |
| `terraform_sa_email` | Service account email to impersonate | -- |

### Azure Cross-Cloud Credentials

| Variable | Description | Required |
|----------|-------------|----------|
| `client_id` | Azure Service Principal Application ID | Yes |
| `client_secret` | Azure Service Principal Secret | Yes |
| `tenant_id` | Azure AD Tenant ID | Yes |
| `subscription_id` | Azure Subscription ID | Yes |

> **Note**: These Azure credentials support cross-cloud integrations (e.g., Key Vault, DNS, artifact store) used alongside this GCP deployment.

### Global

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Grouping label stamped onto every resource | `bigip-gcp-3nic` |
| `resourceOwner` | Owner name for labeling and audit | -- |
| `machine_type` | GCP machine type ([must support 3+ NICs](#machine-type-nic-limits)) | `n2-standard-8` |

### Networking -- Management VPC

| Variable | Description | Default |
|----------|-------------|---------|
| `mgmt_vpc_name` | Management VPC network name | -- |
| `mgmt_subnet_name` | Management subnet name | -- |
| `mgmt_cidr` | Management subnet CIDR | -- |

### Networking -- External VPC

| Variable | Description | Default |
|----------|-------------|---------|
| `external_vpc_name` | External VPC network name | -- |
| `external_subnet_name` | External subnet name | -- |
| `external_cidr` | External subnet CIDR | -- |

### Networking -- Internal VPC

| Variable | Description | Default |
|----------|-------------|---------|
| `internal_vpc_name` | Internal VPC network name | -- |
| `internal_subnet_name` | Internal subnet name | -- |
| `internal_cidr` | Internal subnet CIDR | -- |

### Access Control

| Variable | Description | Default |
|----------|-------------|---------|
| `vpnMgmtSrcAddr` | List of IPs/CIDRs allowed management access (SSH, TMUI) | -- |
| `REtrafficSrcAddr` | List of IPs/CIDRs for Regional Edge / virtual server traffic sources | -- |

> **Note**: The deployer's current public IP is automatically detected and added to the management allowlist.

### BIG-IP VM

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | Compute instance name (blank = auto-generated from `instance_prefix`) | -- |
| `instance_prefix` | Prefix for derived resource names (firewall rules, IPs, service account) | -- |
| `external_gw` | Default gateway for the external subnet (first usable IP, e.g. `10.245.10.1`). Becomes the TMM default route | -- |

### BIG-IP Onboarding

| Variable | Description | Default |
|----------|-------------|---------|
| `bigip-hostname` | BIG-IP hostname | -- |
| `ssh_publickey` | Path to SSH public key file | -- |
| `f5_image_name` | BIG-IP PAYG image name | `f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps` |
| `f5_image_project` | GCP project containing F5 BIG-IP images | `f5-7626-networks-public` |
| `f5_username` | First BIG-IP admin user | -- |
| `f5_username_2` | Second BIG-IP admin user | -- |
| `f5_password` | Password for BIG-IP admin users (sensitive) | -- |
| `dns_suffix` | DNS suffix for BIG-IP hostname | -- |
| `dns_server` | Primary DNS server | -- |
| `ntp_server` | Primary NTP server | -- |
| `timezone` | System timezone | `UTC` |
| `script_name` | Onboarding script template name (without `.tmpl`) | `f5_onboard` |
| `INIT_URL` | F5 BIG-IP Runtime Init download URL | v2.0.3 |

## Outputs

| Output | Description |
|--------|-------------|
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<mgmt_public_ip>` |
| `BIG-IP-UI-ip` | BIG-IP management URL: `https://<mgmt_public_ip>` |
| `BIG-IP-External-VIP` | External virtual server URL: `https://<external_public_ip>` |
| `gcp_console_url` | Direct link to the GCP Console instance detail page |
| `bigip_image` | Resolved BIG-IP image name |
| `onboarding_log_tail` | SSH command to tail `/var/log/cloud/startup-script.log` |
| `serial_console_cmd` | `gcloud` command to view serial port output |
| `management_private_ip` | Management NIC private IP (nic0) |
| `external_public_ip` | External NIC public IP (nic1) |
| `external_private_ip` | External NIC private IP (nic1) |
| `internal_private_ip` | Internal NIC private IP (nic2) |

## GCP Resources Created

| Resource | Purpose |
|----------|---------|
| VPC Network (mgmt) | Isolated network for management traffic |
| VPC Network (external) | Isolated network for external / virtual server traffic |
| VPC Network (internal) | Isolated network for internal / backend traffic |
| Subnet (mgmt) | Management subnet within the mgmt VPC |
| Subnet (external) | External subnet within the external VPC |
| Subnet (internal) | Internal subnet within the internal VPC |
| Firewall Rule (mgmt) | Allows TCP 22, 443 and ICMP from allowlisted management IPs |
| Firewall Rule (external) | Allows TCP 80, 443, 8080, 8081 from RE traffic sources |
| Firewall Rule (internal) | Allows all protocols from 10.0.0.0/8 |
| External IP (mgmt) | Static regional IP for management access |
| External IP (external) | Static regional IP for virtual server traffic (VIP) |
| Internal IP (external) | Pre-allocated private IP for nic1 (BIG-IP Self-IP) |
| Internal IP (internal) | Pre-allocated private IP for nic2 (BIG-IP Self-IP) |
| Compute Instance | F5 BIG-IP VE with 3 NICs, IP forwarding enabled |
| GCS Bucket | Hosts DO and AS3 extension RPMs |
| Bucket Objects (x2) | Declarative Onboarding and AS3 RPM files |
| Service Account | Dedicated SA for BIG-IP GCS access |
| Bucket IAM Binding | Grants the BIG-IP SA `roles/storage.objectViewer` on the RPM bucket |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` startup script:

1. **Sets passwords** for root and admin accounts
2. **Downloads F5 extensions** (DO and AS3 RPMs) from the GCS bucket using an OAuth2 token from the GCP metadata server
3. **Installs F5 BIG-IP Runtime Init**
4. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions modules (Best Plus tier: LTM, ASM, AVR, APM, GTM)
   - **Configures VLAN `external`** on interface 1.1 (nic1)
   - **Configures VLAN `internal`** on interface 1.2 (nic2)
   - **Creates Self-IP** for the external VLAN (pre-allocated `external_self_ip`)
   - **Creates Self-IP** for the internal VLAN (pre-allocated `internal_self_ip`)
   - **Sets the TMM default route** via `external_gw` (the external subnet's gateway)
   - Enables UI advisory banner
5. **Applies Application Services 3 (AS3)** declaration (if configured)

### RPM Delivery via GCS

Extension RPMs are uploaded to a GCS bucket at `terraform apply` time. The BIG-IP downloads them at first boot using an OAuth2 token from the GCP metadata server (via the instance's service account), then installs them from local `file://` paths -- no external network dependency after the initial download.

## Key Differences from Single-NIC

| Feature | Single-NIC | Multi-NIC (3-NIC) |
|---------|-----------|-------------------|
| VPC networks | 1 (mgmt only) | 3 (mgmt, external, internal) |
| Network interfaces | 1 (nic0) | 3 (nic0, nic1, nic2) |
| Firewall rule sets | 1 | 3 (one per VPC) |
| Static external IPs | 1 | 2 (mgmt + external VIP) |
| Pre-allocated internal IPs | 0 | 2 (external + internal Self-IPs) |
| Management GUI port | 8443 (shared NIC) | 443 (dedicated mgmt NIC) |
| DO VLAN/Self-IP config | None | VLANs on 1.1 and 1.2, Self-IPs, TMM default route |
| Minimum vCPUs | 2 | 8 (for 3+ NIC support) |
| `external_gw` variable | Not needed | Required (TMM default route gateway) |

## Network Layout

```
+---------------------+     +---------------------+     +---------------------+
| Management VPC      |     | External VPC        |     | Internal VPC        |
|                     |     |                     |     |                     |
| +-----------------+ |     | +-----------------+ |     | +-----------------+ |
| | mgmt subnet     | |     | | external subnet | |     | | internal subnet | |
| | (user-defined)  | |     | | (user-defined)  | |     | | (user-defined)  | |
| +-----------------+ |     | +-----------------+ |     | +-----------------+ |
|                     |     |                     |     |                     |
| Firewall:           |     | Firewall:           |     | Firewall:           |
|  TCP 22, 443, ICMP  |     |  TCP 80, 443,       |     |  All protocols      |
|  from admin IPs     |     |  8080, 8081          |     |  from 10.0.0.0/8    |
|                     |     |  from RE traffic IPs |     |                     |
+----------+----------+     +----------+----------+     +----------+----------+
           |                           |                           |
           v                           v                           v
         nic0                        nic1                        nic2
     (management)            (external / 1.1)            (internal / 1.2)
           |                           |                           |
           +-----------+---------------+---------------------------+
                       |
                       v
              [ BIG-IP VE Instance ]
              Machine type: n2-standard-8
              IP forwarding: enabled
```

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials, passwords, and Azure cross-cloud secrets.
- Management access is restricted to specific source IPs via the mgmt VPC firewall rule.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- External virtual server traffic is restricted to designated RE traffic source IPs.
- Internal traffic is limited to RFC1918 ranges (10.0.0.0/8).
- RPM downloads use the BIG-IP instance's **dedicated service account** with `roles/storage.objectViewer` on the RPM bucket (no shared keys or broad permissions).
- Service account impersonation avoids exporting long-lived service account keys for Terraform authentication.

## Cleanup

```bash
terraform destroy
```

Or delete the individual resources from the GCP Console using the link provided in the `gcp_console_url` output.

> **Note**: The GCS bucket is created with `force_destroy = true`, so `terraform destroy` will remove it even if it contains objects.
