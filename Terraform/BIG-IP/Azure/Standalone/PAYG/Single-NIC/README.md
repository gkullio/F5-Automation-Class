# F5 BIG-IP Single-NIC Standalone (PAYG) - Azure

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Microsoft Azure using **Pay-As-You-Go (PAYG)** licensing. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init and Declarative Onboarding (DO) -- no manual configuration required.

## Architecture

```
                    Internet
                       |
                       v
              [ Azure Public IP ]
              (Static, Standard SKU)
                       |
                       v
          [ Network Security Group ]
          Ports: 22, 80, 8080, 8081,
                 443, 8443
          Source: allowlisted IPs only
                       |
                       v
    +----------------------------------+
    |        BIG-IP VE (Single NIC)    |
    |   Management Subnet 10.245.1.0/24|
    |                                  |
    |   Modules: LTM, ASM, AVR,        |
    |            APM, GTM (Best)       |
    |                                  |
    |   Onboarded via:                 |
    |     - Runtime Init               |
    |     - Declarative Onboarding     |
    +----------------------------------+
                       |
          Azure VNet (10.245.0.0/16)
```

**Single-NIC design**: All traffic (management and data plane) flows through one interface on the management subnet. This is the simplest BIG-IP topology, suitable for lab, PoC, and training scenarios.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Taskfile](https://taskfile.dev/) (optional, for workflow automation)
- An Azure subscription with a Service Principal assigned a custom role (see below)
- An SSH key pair (if using SSH key authentication)
- F5 BIG-IP Azure Marketplace terms accepted for the selected image

### Create a Custom Azure Role and Service Principal

This deployment creates role assignments (e.g., granting the BIG-IP VM's managed identity blob reader access), which requires permissions beyond the built-in Contributor role. Create a custom role that includes `Microsoft.Authorization/*/Write` while restricting dangerous operations:

This is run within the Azure CLI either on your local machine or from within the Azure Portal CLI.

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
        "Microsoft.Authorization/roleDefinitions/delete",
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

   Save the output -- it contains the `appId` (client_id), `password` (client_secret), and `tenant` (tenant_id) needed for `terraform.tfvars`.

### Accept Marketplace Terms

Before deploying, accept the Azure Marketplace terms for the BIG-IP image:

```bash
az vm image terms accept \
  --publisher f5-networks \
  --offer f5-big-ip-best \
  --plan f5-big-best-plus-hourly-25mbps
```

## Project Structure

```
Single-NIC/
├── main.tf                         # Root module: resource group, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH command, WebUI URL, portal link
├── providers.tf                    # Provider configuration (azurerm ~>4.0)
├── terraform.tfvars.boilerplate    # Template with empty placeholders
├── taskfile.yml                    # Taskfile v3 automation
└── modules/
    ├── azure-vnet/
    │   ├── main.tf                 # VNet + management subnet
    │   ├── variables.tf
    │   └── outputs.tf
    └── bigip/
        ├── main.tf                 # Boot diagnostics storage account
        ├── bigip.tf                # BIG-IP Linux VM
        ├── network.tf              # Public IP, NSG, NIC
        ├── storage.tf              # RPM blob storage + SAS token
        ├── variables.tf
        ├── bigip_outputs.tf
        ├── f5_onboard.tmpl         # Cloud-init onboarding script template
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

   This runs `init` -> `validate` -> `plan` -> `apply` sequentially.

3. **Or deploy with Terraform directly**

   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```

4. **Access the BIG-IP**

   After deployment, Terraform outputs:
   - **SSH**: `ssh admin@<public_ip>`
   - **WebUI**: `https://<public_ip>:8443`
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
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<public_ip>` |
| `BIG-IP-WebUI` | BIG-IP management URL: `https://<public_ip>:8443` |
| `resource_group_portal_url` | Direct link to the Azure Portal resource group |

## Azure Resources Created

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all deployed resources |
| Virtual Network | Network backbone (10.245.0.0/16) |
| Subnet (mgmt) | Single subnet for all BIG-IP traffic |
| Public IP | Static, Standard SKU for management/data access |
| Network Security Group | Inbound rules for ports 22, 80, 8080, 8081, 443, 8443 |
| Network Interface | Single NIC attached to management subnet |
| Linux Virtual Machine | F5 BIG-IP VE (PAYG, Best license tier) |
| Storage Account (diagnostics) | VM boot diagnostics |
| Storage Account (RPMs) | Hosts DO and AS3 extension RPMs |
| Blob Container | Container for RPM blobs |
| Storage Blobs (x2) | Declarative Onboarding and AS3 RPM files |

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
   - Enables UI advisory banner

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
- Management access is restricted to specific source IPs via NSG rules.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- RPM downloads use a read-only SAS token with a 30-day expiry.
- The BIG-IP VM uses a system-assigned managed identity.

## Cleanup

```bash
terraform destroy
```

Or remove the resource group directly from the Azure Portal using the link provided in the `resource_group_portal_url` output.
