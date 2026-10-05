# F5 BIG-IP Single-NIC with App Service (PAYG) - Azure

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Microsoft Azure using **Pay-As-You-Go (PAYG)** licensing, configured as a **reverse proxy** in front of a privately-accessible **Azure App Service** running a Docker container. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init, Declarative Onboarding (DO), and Application Services 3 (AS3) -- no manual configuration required.

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
    +------------------------------------+
    |        BIG-IP VE (Single NIC)      |
    |   Management Subnet 10.245.1.0/24  |
    |                                    |
    |   Module: LTM (Good tier)          |
    |                                    |
    |   HTTPS Virtual Server (port 443)  |
    |     - TLS termination (clientssl)  |
    |     - Host header rewrite (iRule)  |
    |     - X-Forwarded-For enabled      |
    +------------------------------------+
                   | (private, within VNet)
                   v
          [ Private Endpoint ]
          (mgmt subnet)
                   |
                   v
    +------------------------------------+
    |     Azure Linux Web App            |
    |   Docker: stockdemo/demoapp:latest |
    |   Port: 8080                       |
    |   Public access: DISABLED          |
    +------------------------------------+
          Private DNS Zone:
          privatelink.azurewebsites.net

          Azure VNet (10.245.0.0/16)
```

### Traffic Flow

1. External clients connect to the BIG-IP's public IP on **port 443** (HTTPS)
2. BIG-IP **terminates TLS** using the default `clientssl` profile
3. An **iRule rewrites the Host header** to the App Service's FQDN
4. BIG-IP adds **X-Forwarded-For** headers
5. Traffic is forwarded to the App Service's **private endpoint IP on port 80**
6. The App Service is **only reachable via the private endpoint** -- public internet access is disabled

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Taskfile](https://taskfile.dev/) (optional, for workflow automation)
- An Azure subscription with a Service Principal assigned a custom role (see below)
- An SSH key pair (if using SSH key authentication)
- F5 BIG-IP Azure Marketplace terms accepted for the selected image

### Create a Custom Azure Role and Service Principal

This section is necessary to create the specific role assignments (e.g., granting the BIG-IP VM's managed identity blob reader access), which requires permissions beyond the built-in Contributor role. Create a custom role that includes `Microsoft.Authorization/*/Write` while restricting dangerous operations:

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
Single-NIC-app/
├── main.tf                         # Root module: resource group, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, portal link, private endpoint IP
├── providers.tf                    # Provider configuration (azurerm ~>4.0)
├── terraform.tfvars.boilerplate    # Template with empty placeholders
├── taskfile.yml                    # Taskfile v3 automation
└── modules/
    ├── azure-vnet/
    │   ├── main.tf                 # VNet + management subnet
    │   ├── variables.tf
    │   └── outputs.tf
    ├── app-service/
    │   ├── main.tf                 # App Service Plan, Web App, Private Endpoint, DNS
    │   ├── variables.tf
    │   └── outputs.tf
    └── bigip/
        ├── main.tf                 # Boot diagnostics storage account
        ├── bigip.tf                # BIG-IP Linux VM
        ├── network.tf              # Public IP, NSG, NIC
        ├── storage.tf              # RPM blob storage + managed identity access
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

2. **Deploy with Taskfile** (***recommended only if installed***)

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
   - **App Service Private IP**: The private endpoint IP (accessible only within the VNet)

5. **Test the application**

   Browse to `https://<public_ip>` -- the BIG-IP proxies the request to the App Service via its private endpoint.

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
| `resourceOwner` | Owner name for tagging and audit | -- |
| `ownerEmail` | Owner email for tagging | -- |
| `location` | Azure region | -- |
| `instance_size` | VM size ([sizing guide](https://clouddocs.f5.com/cloud/public/v1/matrix.html#microsoft-azure)) | `Standard_D8s_v5` |

### App Service

| Variable | Description | Default |
|----------|-------------|---------|
| `app_name` | Web application name | -- |
| `create_service_plan` | Create a new App Service Plan (set `false` to reuse existing) | `true` |
| `existing_service_plan_id` | ID of existing plan (when `create_service_plan = false`) | `null` |
| `service_plan_name` | App Service Plan name | -- |
| `sku_name` | App Service Plan SKU | `B1` |
| `docker_image` | Docker image to run | `stockdemo/demoapp:latest` |
| `docker_registry_url` | Docker registry URL | `https://index.docker.io` |
| `app_port` | Application listening port | `8080` |
| `always_on` | Keep the app always running | `true` |
| `https_only` | Restrict App Service to HTTPS only | `false` |
| `extra_app_settings` | Additional app settings (key-value map) | `null` |

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
| `f5_product_name` | Azure Marketplace offer name | `f5-big-ip-good` |
| `f5_image_name` | Azure Marketplace SKU | `f5-bigip-virtual-edition-25m-good-hourly` |
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
| `app_service_private_endpoint_ip` | Private IP of the App Service endpoint (VNet-only) |

## Azure Resources Created

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all deployed resources |
| Virtual Network | Network backbone (10.245.0.0/16) |
| Subnet (mgmt) | Single subnet for all BIG-IP and private endpoint traffic |
| Public IP | Static, Standard SKU for management/data access |
| Network Security Group | Inbound rules for ports 22, 80, 8080, 8081, 443, 8443 |
| Network Interface | Single NIC attached to management subnet |
| Linux Virtual Machine | F5 BIG-IP VE (PAYG, Good license tier) |
| Storage Account (diagnostics) | VM boot diagnostics |
| Storage Account (RPMs) | Hosts DO and AS3 extension RPMs |
| Blob Container + Blobs (x2) | Declarative Onboarding and AS3 RPM files |
| Role Assignment | Grants BIG-IP managed identity blob reader access |
| App Service Plan | Linux plan (B1 SKU) for the web app |
| Linux Web App | Docker container running the demo application |
| Private Endpoint | Connects the App Service to the VNet privately |
| Private DNS Zone | `privatelink.azurewebsites.net` for internal DNS resolution |
| DNS Zone VNet Link | Links the private DNS zone to the VNet |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` cloud-init script:

1. **Sets passwords** for root and admin accounts
2. **Downloads F5 extensions** (DO and AS3 RPMs) from Azure Blob Storage using the VM's system-assigned managed identity
3. **Installs F5 BIG-IP Runtime Init**
4. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions LTM module (Good tier)
   - Enables UI advisory banner
5. **Applies Application Services 3 (AS3)** declaration:
   - Creates tenant `Demo_Application`
   - Configures an HTTPS virtual server on port 443
   - Terminates TLS with the `clientssl` profile
   - Applies an iRule to rewrite the Host header to the App Service FQDN
   - Enables X-Forwarded-For via HTTP profile
   - Creates a pool (`demo_app_http_pool`) with the App Service private endpoint IP as the sole member on port 80

## Key Differences from Single-NIC

| Feature | Single-NIC | Single-NIC-app |
|---------|-----------|----------------|
| Backend application | None | Azure App Service with Private Endpoint |
| License tier | Best (LTM, ASM, AVR, APM, GTM) | Good (LTM only) |
| AS3 declaration | No | Yes (HTTPS virtual server + pool) |
| RPM download method | SAS token | Managed identity |
| Modules | azure-vnet, bigip | azure-vnet, bigip, app-service |

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
- The App Service has **public network access disabled** -- it is only reachable through the private endpoint within the VNet.
- RPM downloads use the BIG-IP VM's **system-assigned managed identity** with Storage Blob Data Reader role (no shared keys or SAS tokens).
- Private DNS ensures the App Service FQDN resolves to its private IP within the VNet.

## Cleanup

```bash
terraform destroy
```

Or remove the resource group directly from the Azure Portal using the link provided in the `resource_group_portal_url` output.
