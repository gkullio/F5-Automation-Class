# F5 BIG-IP Single-NIC (PAYG) - AWS

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Amazon Web Services using **Pay-As-You-Go (PAYG)** licensing. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init, Declarative Onboarding (DO), and Application Services 3 (AS3) -- no manual configuration required. The single interface carries both management and data-plane traffic, with the GUI accessible on **port 8443** so that port 443 remains available for virtual servers. RPM extensions are delivered via a private **S3 bucket** using the instance's **IAM role** credentials.

## Architecture

```
                      Internet
                         |
                         v
                 [ Elastic IP ]
              (Static, VPC-scoped)
                         |
                         v
              [ Security Group ]
              Admin:  22, 8443
              App:    80, 443, 8080, 8081
              Source: allowlisted IPs only
              Egress: all outbound (required)
                         |
                         v
    +------------------------------------+
    |        BIG-IP VE (Single NIC)      |
    |   Management Subnet (AZ-pinned)    |
    |   source_dest_check = false        |
    |                                    |
    |   Modules: LTM, ASM, AVR, APM,    |
    |            GTM (Best tier)         |
    |                                    |
    |   Management GUI on port 8443      |
    |   Virtual servers on port 443      |
    +------------------------------------+
              |
              v
    [ IAM Instance Profile ]
    (S3 GetObject for RPM bucket)

    AWS VPC
    +-- Subnet (mgmt, single AZ)
    +-- Internet Gateway
    +-- Route Table (0.0.0.0/0 -> IGW)
    +-- Route Table Association
```

### Traffic Flow

1. External clients connect to the BIG-IP's Elastic IP on the desired port (e.g., **443** for HTTPS)
2. The security group allows inbound traffic from allowlisted source CIDRs
3. BIG-IP processes traffic through virtual servers configured via AS3
4. Management access (SSH, WebUI) is on ports **22** and **8443**, restricted to admin source addresses
5. RPM extensions (DO, AS3) are downloaded from a private **S3 bucket** using the instance's **IAM role** credentials via SigV4-signed requests

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with SSO or environment credentials (`aws sso login --profile <name>`)
- Azure CLI / Service Principal (for cross-cloud DNS, Key Vault, and artifact-store dependencies)
- An SSH key pair
- F5 BIG-IP AWS Marketplace offer accepted for the PAYG AMI

### AWS Authentication

This project does **not** use `access_key` / `secret_key` variables. The AWS provider resolves credentials in this order:

1. **`aws_profile`** -- named profile from `~/.aws/config` (local SSO runs)
2. **`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`** -- environment variables (GitHub Actions OIDC)
3. **EC2 instance role** -- when running from an EC2 instance

Leave `aws_profile` empty in CI so environment credentials are used.

### Accept Marketplace Terms

Before deploying, accept the AWS Marketplace terms for the BIG-IP PAYG AMI. This is a one-time step per AWS account:

1. Visit the [F5 BIG-IP VE - Best Plus (PAYG, 25Mbps)](https://aws.amazon.com/marketplace) listing in the AWS Marketplace console
2. Click **Continue to Subscribe** and accept the terms

Confirm available AMIs in your region:

```bash
aws ec2 describe-images --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17*PAYG*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table
```

### Azure Cross-Cloud Dependencies

Several shared resources live in Azure and are referenced by this AWS project:

| Dependency | Where It Lives | Why It Stayed |
|------------|----------------|---------------|
| `kulland.info` DNS zone | Azure DNS | The zone already exists; an A-record pointing at an Elastic IP works from anywhere |
| Wildcard TLS certificate | Azure Key Vault | Avoids duplicating the cert into AWS Secrets Manager |
| CrowdStrike sensor artifacts | Azure Blob Storage | Fetched over HTTPS with a SAS token; works identically from EC2 |

The Azure Service Principal credentials (`client_id`, `client_secret`, `tenant_id`, `subscription_id`) are required for these cross-cloud lookups.

## Project Structure

```
Single-NIC/
+-- main.tf                         # Root module: public IP lookup, module calls
+-- variables.tf                    # All root-level input variables
+-- outputs.tf                      # SSH, WebUI, EC2 console link, AMI info
+-- providers.tf                    # Provider config (aws ~>5.0, http ~>3.0, time ~>0.9)
+-- terraform.tfvars.boilerplate    # Template with empty placeholders
+-- modules/
    +-- aws-vpc/
    |   +-- main.tf                 # VPC, subnet, internet gateway, route table
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- bigip/
        +-- bigip.tf                # EC2 instance (BIG-IP VE)
        +-- network.tf              # AMI lookup, security group, key pair, EIP
        +-- s3.tf                   # S3 bucket, RPM objects, IAM role + profile
        +-- variables.tf
        +-- bigip_outputs.tf
        +-- f5_onboard.tmpl         # Cloud-init onboarding script template
        +-- rpm_files/
            +-- f5-declarative-onboarding-1.49.0-14.noarch.rpm
            +-- f5-appsvcs-3.57.0-13.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   ```bash
   cp terraform.tfvars.boilerplate terraform.tfvars
   ```

   Edit `terraform.tfvars` and fill in all required values (see [Variables](#variables) below).

2. **Authenticate to AWS**

   ```bash
   aws sso login --profile <your-profile>
   ```

3. **Deploy with Terraform**

   ```bash
   terraform init -upgrade
   terraform validate
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```

4. **Access the BIG-IP**

   After deployment, Terraform outputs:
   - **SSH**: `ssh admin@<elastic_ip>`
   - **WebUI**: `https://<elastic_ip>:8443`
   - **EC2 Console**: Direct link to the instance in the AWS console
   - **AMI**: The resolved AMI name and ID

5. **Troubleshoot onboarding**

   If the GUI is up but no modules are provisioned, tail the startup log:

   ```bash
   ssh -t admin@<elastic_ip> 'run util bash -c "tail -f /var/log/cloud/startup-script.log"'
   ```

## Variables

### AWS Credentials

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region to deploy into (e.g., `us-east-1`) | -- |
| `aws_profile` | Named profile from `~/.aws/config` for local SSO runs; leave empty in CI | `""` |

### Azure Cross-Cloud Credentials

| Variable | Description | Required |
|----------|-------------|----------|
| `client_id` | Azure Service Principal Application ID | Yes |
| `client_secret` | Azure Service Principal Secret | Yes |
| `tenant_id` | Azure AD Tenant ID | Yes |
| `subscription_id` | Azure Subscription ID | Yes |

### Global

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Grouping label stamped on every resource via `default_tags` | `bigip-aws-1nic` |
| `resourceOwner` | Owner name for tagging | -- |
| `instance_size` | EC2 instance type ([sizing guide](https://clouddocs.f5.com/cloud/public/v1/matrix.html#amazon-web-services)) | -- |

### Networking

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_name` | VPC name | -- |
| `vpc_cidr` | VPC CIDR block | -- |
| `mgmt_subnet_name` | Management subnet name | -- |
| `mgmt_cidr` | Management subnet CIDR | -- |
| `availability_zone` | Full AZ name (e.g., `us-east-1a`) -- AWS subnets are AZ-scoped | -- |

### Access Control

| Variable | Description | Default |
|----------|-------------|---------|
| `vpnMgmtSrcAddr` | List of IPs/CIDRs allowed management access (SSH, WebUI on 8443) | -- |
| `REtrafficSrcAddr` | List of IPs/CIDRs for application traffic (ports 80, 443, 8080, 8081) | -- |

> **Note**: The deployer's current public IP is automatically detected and added to the management allowlist.

### BIG-IP VM

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | Instance Name tag | -- |
| `instance_prefix` | Prefix for derived resource names (SG, EIP, key pair, S3 bucket) | -- |

### BIG-IP Onboarding

| Variable | Description | Default |
|----------|-------------|---------|
| `bigip-hostname` | BIG-IP hostname | -- |
| `ssh_publickey` | Path to SSH public key file | -- |
| `f5_ami_search_name` | Wildcard match for the BIG-IP AMI name | `*BIGIP-17*PAYG-Best Plus 25Mbps*` |
| `f5_ami_owner` | AMI owner filter | `aws-marketplace` |
| `f5_username` | First BIG-IP admin user | -- |
| `f5_username_2` | Second BIG-IP admin user | -- |
| `f5_password` | Password for both BIG-IP users (sensitive) | -- |
| `dns_suffix` | DNS suffix for BIG-IP hostname | -- |
| `dns_server` | Primary DNS server | -- |
| `dns_record_name` | A-record hostname in the DNS zone | `bigip-1nic-aws` |
| `ntp_server` | Primary NTP server | -- |
| `timezone` | System timezone | -- |
| `script_name` | Onboarding template name (without `.tmpl`) | -- |
| `INIT_URL` | F5 BIG-IP Runtime Init download URL | v2.0.3 |
| `key_vault_name` | Azure Key Vault storing the wildcard certificate | -- |
| `key_vault_rg` | Resource group containing the Key Vault | `kulland-house-keys` |

### CrowdStrike

| Variable | Description | Default |
|----------|-------------|---------|
| `crowdstrike_enabled` | Install the CrowdStrike Falcon sensor during onboarding | `true` |
| `cs_cid` | CrowdStrike Customer ID (32 hex + hyphen + 2-char checksum, sensitive) | `""` |
| `cs_tags_bigip` | Falcon sensor grouping tags (comma-separated) | `""` |
| `cs_provisioning_token` | Falcon installation token (sensitive) | `""` |
| `cs_sas_validity_hours` | Lifetime of the read-only SAS token for sensor packages | `8760` (1 year) |

## Outputs

| Output | Description |
|--------|-------------|
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<elastic_ip>` |
| `BIG-IP-UI-ip` | BIG-IP management URL: `https://<elastic_ip>:8443` |
| `ec2_console_url` | Direct link to the EC2 instance in the AWS console |
| `bigip_ami` | Resolved AMI name and ID |
| `onboarding_log_tail` | SSH command to tail the startup log for troubleshooting |
| `console_output_cmd` | AWS CLI command to retrieve boot-time console output |

## AWS Resources Created

| Resource | Purpose |
|----------|---------|
| VPC | Network backbone with DNS support and DNS hostnames enabled |
| Subnet (mgmt) | Single subnet pinned to one availability zone |
| Internet Gateway | Provides outbound internet access (required for onboarding) |
| Route Table | Default route (0.0.0.0/0) pointing to the internet gateway |
| Route Table Association | Binds the mgmt subnet to the public route table |
| Security Group | Inbound rules for ports 22, 8443 (admin) and 80, 443, 8080, 8081 (app); all egress |
| Key Pair | SSH key pair for instance access |
| Elastic IP | Static public IP (VPC-scoped) for management and data access |
| EIP Association | Binds the Elastic IP to the BIG-IP instance |
| EC2 Instance | F5 BIG-IP VE (PAYG Best Plus 25Mbps, IMDSv2 required) |
| S3 Bucket | Hosts DO and AS3 extension RPMs (private, SSE-AES256) |
| S3 Public Access Block | Blocks all public access to the RPM bucket |
| S3 Encryption Config | Server-side encryption (AES256) for the RPM bucket |
| S3 Objects (x2) | Declarative Onboarding and AS3 RPM files |
| IAM Role | EC2 assume-role for S3 access |
| IAM Role Policy | Grants `s3:GetObject` on the two RPM objects only |
| IAM Instance Profile | Attaches the IAM role to the EC2 instance |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` cloud-init script:

1. **Sets passwords** for root and admin accounts
2. **Tunes system databases** (extra memory for restjavad, extended timeouts for iApps LX)
3. **Writes the runtime-init config** (`/config/cloud/runtime-init-conf.yaml`) with static parameters for hostname, region, DNS, NTP, timezone, and credentials
4. **Downloads F5 extensions** (DO and AS3 RPMs) from S3 using an inline Python script that mints IMDSv2 tokens and makes SigV4-signed requests -- no AWS CLI or boto3 required
5. **Downloads and installs F5 BIG-IP Runtime Init** from GitHub
6. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions modules: LTM, ASM, AVR, APM, GTM (Best tier)
   - Enables UI advisory banner
7. **Installs AS3** extension (ready for declarations)

### RPM Delivery: S3 + IAM Role

Unlike the Azure projects which use blob storage with managed identity or SAS tokens, this project:

- Uploads the DO and AS3 RPMs from `modules/bigip/rpm_files/` to a **private S3 bucket** at apply time
- Grants the BIG-IP's **IAM instance profile** read-only access (`s3:GetObject`) scoped to the two RPM objects
- The onboarding script uses a built-in Python helper (`s3_download.py`) that handles **IMDSv2 token retrieval** and **SigV4 request signing** using only Python stdlib

### CrowdStrike Toggle

`crowdstrike_enabled` (default `true`) drives the sensor install from one place in `terraform.tfvars`. It fans out to both consumers -- the artifact-lookup module (which resolves sensor blob URLs and mints a SAS token) and the bigip module (which gates the install block in the onboarding template).

When disabled (`false`):
- No CrowdStrike blob lookups, so no SAS token is written into state
- The install block is removed from the rendered `user_data` by a `templatefile` `if` directive
- `cs_cid`, `cs_tags_bigip`, and `cs_provisioning_token` can all stay empty

When enabled with an empty `cs_cid`, or enabled in one module but not the other, the deploy fails at plan time via a precondition on `aws_instance.bigip` rather than twenty minutes into cloud-init.

## Key Differences from Azure Single-NIC

| Feature | Azure Single-NIC | AWS Single-NIC (PAYG) |
|---------|------------------|------------------------|
| Authentication | Service Principal (`client_id`/`client_secret`) | SSO profile or environment credentials (no static keys) |
| Network container | Resource Group | `project_name` tag via provider `default_tags` |
| Network module | VNet + Subnet | VPC + Subnet + Internet Gateway + Route Table + Association |
| Public IP | `azurerm_public_ip` (Static, Standard SKU) | `aws_eip` (VPC-scoped) + `aws_eip_association` |
| Security | Network Security Group (priority-based) | Security Group (allow-list only, egress deny-all by default) |
| Boot diagnostics | Storage Account | `aws ec2 get-console-output` (built-in, no extra resource) |
| Image selection | `source_image_reference` + `plan` block | `data "aws_ami"` wildcard search + Marketplace subscription |
| RPM delivery | Blob Storage + managed identity | S3 bucket + IAM instance profile |
| Availability zone | Bare number (`1`) | Full AZ name (`us-east-1a`), immutable on the subnet |
| Hostname/region | IMDS metadata lookup | Static values from Terraform (IMDSv2 compatibility) |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials and passwords.
- **No static AWS keys**: authentication uses SSO profiles or environment credentials, never `access_key`/`secret_key` variables.
- Management access (SSH, WebUI) is restricted to specific source CIDRs via security group rules.
- The deployer's public IP is automatically detected and added to the admin allowlist.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- The S3 RPM bucket is **fully private** (public access blocked) with **AES256 server-side encryption**.
- RPM downloads use the BIG-IP's **IAM instance profile** with least-privilege S3 access (two specific objects only).
- **IMDSv2 is required** (`http_tokens = "required"`) -- the onboarding template handles token minting correctly.
- The root EBS volume is **encrypted by default**.
- `source_dest_check` is disabled on the instance (required for single-NIC data-plane forwarding).
- Editing `f5_onboard.tmpl` **rebuilds the instance** (`user_data_replace_on_change = true`) rather than silently updating a running instance that never re-reads user_data.

## Cleanup

```bash
terraform destroy
```

> **Note**: Unlike Azure, AWS has no resource group to delete as a single unit. All resources are tagged with `project` and `owner` via provider `default_tags` for easy identification. Use the `ec2_console_url` output to navigate directly to the instance, or filter the AWS console on the `project_name` tag to find all deployed resources.
