# F5 BIG-IP Multi-NIC Standalone (PAYG) - Azure

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **3-NIC topology** on Microsoft Azure using **Pay-As-You-Go (PAYG)** licensing. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init and Declarative Onboarding (DO) -- no manual configuration required.

## Architecture

```
                      Internet
                         |
            +------------+------------+
            |                         |
   [ Mgmt Public IP ]       [ Ext Public IP ]
            |                         |
            v                         v
  +--- Management NIC ----+  +--- External NIC ----+
  | Subnet: mgmt          |  | Subnet: ext         |
  | 10.245.1.0/24         |  | 10.245.2.0/24       |
  | NSG: SSH, 443, 8443   |  | NSG: 80, 443,       |
  | Source: admin IPs     |  |   8080, 8081, 8443  |
  +-----------+-----------+  | Source: admin +     |
              |              |   RE traffic IPs    |
              |              +---------+-----------+
              |                        |
         +----+------------------------+----+
         |         BIG-IP VE (3-NIC)        |
         |                                  |
         |   Modules: LTM, ASM, AVR,        |
         |            APM, GTM (Best)       |
         |                                  |
         |   VLANs:                         |
         |     external (1.1) + self-IP     |
         |     internal (1.2) + self-IP     |
         |                                  |
         |   Onboarded via:                 |
         |     - Runtime Init               |
         |     - Declarative Onboarding     |
         +----+-----------------------------+
              |
  +--- Internal NIC ------+
  | Subnet: int           |
  | 10.245.3.0/24         |
  | NSG: Allow all from   |
  |   VirtualNetwork      |
  +-----------------------+

       Azure VNet (10.245.0.0/16)
```

**3-NIC design**: Separates management, external (client-facing), and internal (server-side) traffic onto dedicated interfaces and subnets. This is the recommended production topology, providing network isolation between management, ingress, and backend traffic.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Taskfile](https://taskfile.dev/) (optional, for workflow automation)
- An Azure subscription with a Service Principal assigned a custom role (see below)
- An SSH key pair (if using SSH key authentication)
- F5 BIG-IP Azure Marketplace terms accepted for the selected image

### Create a Custom Azure Role and Service Principal

Create a custom role that includes `Microsoft.Authorization/*/Write` while restricting dangerous operations:

1. **Save the following role definition** to a file (e.g., `custom-role.json`):

   ```json
   {
     "Name": "<your custom role name>",
     "IsCustom": true,
     "Description": "Contributor access with ability to create and manage role assignments.",
     "Actions": [
       "*"
     ],
     "NotActions": [
       "Microsoft.Authorization/*/Delete",
       "Microsoft.Authorization/elevateAccess/Action",
       "Microsoft.Blueprint/blueprintAssignments/write",
       "Microsoft.Blueprint/blueprintAssignments/delete"
     ],
     "DataActions": [],
     "NotDataActions": [],
     "AssignableScopes": [
       "/subscriptions/<your subscription ID>"
     ]
   }
   ```

2. **Create the custom role**:

   ```bash
   az role definition create --role-definition custom-role.json
   ```

3. **Create a Service Principal** with the custom role:

   ```bash
   az ad sp create-for-rbac \
     --name <name> \
     --role "<your custom role name>" \
     --scopes /subscriptions/<your subscription ID>
   ```

### Accept Marketplace Terms

```bash
az vm image terms accept \
  --publisher f5-networks \
  --offer f5-big-ip-best \
  --plan f5-big-best-plus-hourly-25mbps
```

## Project Structure

```
Multi-NIC/
├── main.tf                         # Root module: resource group, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, portal link, external IP
├── providers.tf                    # Provider configuration (azurerm ~>4.0)
├── terraform.tfvars.boilerplate    # Template with empty placeholders
├── taskfile.yml                    # Taskfile v3 automation
└── modules/
    ├── azure-vnet/
    │   ├── main.tf                 # VNet + mgmt/ext/int subnets
    │   ├── variables.tf
    │   └── outputs.tf
    └── bigip/
        ├── main.tf                 # Boot diagnostics storage account
        ├── bigip.tf                # BIG-IP Linux VM (3 NICs)
        ├── network.tf              # 2 public IPs, 3 NSGs, 3 NICs
        ├── storage.tf              # RPM blob storage + SAS token
        ├── variables.tf
        ├── bigip_outputs.tf
        ├── f5_onboard.tmpl         # Cloud-init with VLAN + Self-IP config
        └── rpm_files/
            ├── f5-declarative-onboarding-*.noarch.rpm
            └── f5-appsvcs-*.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   ```bash
   cp terraform.tfvars.boilerplate terraform.tfvars
   ```

   Edit `terraform.tfvars` and fill in all required values (see [Variables](#variables) below).

2. **Deploy with Taskfile** (recommended)

   ```bash
   task deploy
   ```

3. **Or deploy with Terraform directly**

   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```

4. **Access the BIG-IP**

   After deployment, Terraform outputs:
   - **SSH**: `ssh admin@<mgmt_public_ip>`
   - **WebUI**: `https://<mgmt_public_ip>:8443`
   - **External IP**: The public IP for application traffic
   - **Azure Portal**: Direct link to the resource group

## Variables

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
| `rg_name` | Resource group name | -- |
| `resourceOwner` | Owner name/email for tagging and audit | -- |
| `location` | Azure region | -- |
| `instance_size` | VM size ([sizing guide](https://clouddocs.f5.com/cloud/public/v1/matrix.html#microsoft-azure)) | `Standard_D8s_v5` |

### Networking

| Variable | Description | Default |
|----------|-------------|---------|
| `vnet_name` | Virtual network name | -- |
| `vnet_address_space` | VNet CIDR block | `10.245.0.0/16` |
| `mgmt_subnet_name` | Management subnet name | `mgmt` |
| `mgmt_address_space` | Management subnet CIDR | `10.245.1.0/24` |
| `ext_subnet_name` | External subnet name | `ext` |
| `ext_address_space` | External subnet CIDR | `10.245.2.0/24` |
| `int_subnet_name` | Internal subnet name | `int` |
| `int_address_space` | Internal subnet CIDR | `10.245.3.0/24` |

### Access Control

| Variable | Description | Default |
|----------|-------------|---------|
| `vpnMgmtSrcAddr` | List of IPs/CIDRs allowed management access (SSH, WebUI) | -- |
| `REtrafficSrcAddr` | List of IPs/CIDRs for Regional Edge traffic sources | -- |

> **Note**: The deployer's current public IP is automatically detected and added to the management allowlist.

### BIG-IP VM

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | Virtual machine name | -- |
| `instance_prefix` | Prefix for derived resources (e.g., OS disk name) | -- |
| `bigip-username` | Azure VM admin username | -- |
| `bigip-password` | Azure VM admin password | -- |

### BIG-IP Onboarding

| Variable | Description | Default |
|----------|-------------|---------|
| `bigip-hostname` | BIG-IP hostname | -- |
| `ssh_publickey` | Path to SSH public key file | `~/.ssh/id_rsa.pub` |
| `f5_product_name` | Azure Marketplace offer name | `f5-big-ip-best` |
| `f5_image_name` | Azure Marketplace SKU | `f5-big-best-plus-hourly-25mbps` |
| `f5_version` | BIG-IP image version | -- |
| `f5_username` | First BIG-IP admin user | -- |
| `f5_username_2` | Second BIG-IP admin user | -- |
| `f5_password` | Password for both BIG-IP users | -- |
| `dns_suffix` | DNS suffix for BIG-IP hostname | -- |
| `dns_server` | Primary DNS server | `8.8.8.8` |
| `availability_zone` | Azure availability zone | `1` |
| `ntp_server` | Primary NTP server | `0.us.pool.ntp.org` |
| `timezone` | System timezone | `US/Pacific` |
| `enable_ssh_key` | Enable SSH key authentication | `false` |
| `INIT_URL` | F5 BIG-IP Runtime Init download URL | v2.0.3 |

## Outputs

| Output | Description |
|--------|-------------|
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<mgmt_public_ip>` |
| `BIG-IP-WebUI` | BIG-IP management URL: `https://<mgmt_public_ip>:8443` |
| `BIG-IP-External-IP` | External public IP for application traffic |
| `resource_group_portal_url` | Direct link to the Azure Portal resource group |

## Azure Resources Created

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all deployed resources |
| Virtual Network | Network backbone (10.245.0.0/16) |
| Subnet (mgmt) | Management traffic |
| Subnet (ext) | External / client-facing traffic |
| Subnet (int) | Internal / server-side traffic |
| Public IP (mgmt) | Static, Standard SKU for SSH/WebUI access |
| Public IP (ext) | Static, Standard SKU for application traffic |
| NSG (mgmt) | Allows SSH, 443, 8443 from admin IPs |
| NSG (ext) | Allows 80, 443, 8080, 8081, 8443 from admin + RE IPs |
| NSG (int) | Allows all from VirtualNetwork |
| NIC (mgmt) | Management interface with public IP |
| NIC (ext) | External interface with public IP |
| NIC (int) | Internal interface (private only) |
| Linux Virtual Machine | F5 BIG-IP VE (PAYG, Best license tier) |
| Storage Account (diagnostics) | VM boot diagnostics |
| Storage Account (RPMs) | Hosts DO and AS3 extension RPMs |
| Blob Container + Blobs (x2) | Declarative Onboarding and AS3 RPM files |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` cloud-init script:

1. **Sets passwords** for root and admin accounts
2. **Downloads F5 extensions** (DO and AS3 RPMs) from Azure Blob Storage using a time-limited SAS token
3. **Installs F5 BIG-IP Runtime Init**
4. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions modules: LTM, ASM, AVR, APM, GTM (Best tier)
   - **Creates VLANs**: `external` (interface 1.1) and `internal` (interface 1.2)
   - **Creates Self-IPs** for external and internal VLANs
   - Enables UI advisory banner

## Key Differences from Single-NIC

| Feature | Single-NIC | Multi-NIC |
|---------|-----------|-----------|
| NICs | 1 (mgmt) | 3 (mgmt, ext, int) |
| Subnets | 1 | 3 |
| Public IPs | 1 (mgmt) | 2 (mgmt + ext) |
| NSGs | 1 | 3 (per-NIC) |
| VLANs in DO | None | external (1.1), internal (1.2) |
| Self-IPs in DO | None | external + internal |
| Traffic isolation | All on one interface | Mgmt / client / server separated |

## Taskfile Commands

| Command | Description |
|---------|-------------|
| `task init` | `terraform init -upgrade` |
| `task validate` | `terraform validate` |
| `task plan` | `terraform plan -out=tfplan` |
| `task apply` | `terraform apply "tfplan"` (cleans up plan file after) |
| `task deploy` | Full pipeline: init -> validate -> plan -> apply |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials and passwords.
- Management access is restricted to specific source IPs via the management NSG.
- External NSG allows application traffic from admin and RE traffic source IPs.
- Internal NSG allows all VNet traffic (server-side communication).
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- RPM downloads use a read-only SAS token with a 30-day expiry.

## Cleanup

```bash
terraform destroy
```

Or remove the resource group directly from the Azure Portal using the link provided in the `resource_group_portal_url` output.
