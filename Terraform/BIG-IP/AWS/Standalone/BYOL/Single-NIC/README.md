# F5 BIG-IP Single-NIC (BYOL) - AWS

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **single-NIC topology** on Amazon Web Services using **Bring-Your-Own-License (BYOL)** licensing. A valid F5 registration key is applied at boot time via the Declarative Onboarding (DO) `myLicense` class. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init, DO, and Application Services 3 (AS3) -- no manual configuration required. The single interface carries both management and data-plane traffic, with the GUI accessible on **port 8443** so that port 443 remains available for virtual servers. RPM extensions are delivered via a private **S3 bucket** using the instance's **IAM role** credentials.

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
    |   BYOL License (regKey via DO)     |
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
6. The BYOL registration key is applied during DO onboarding via the `myLicense` class

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with SSO or environment credentials (`aws sso login --profile <name>`)
- Azure CLI / Service Principal (for cross-cloud DNS, Key Vault, and artifact-store dependencies)
- An SSH key pair
- A valid **F5 BIG-IP BYOL registration key**
- F5 BIG-IP AWS Marketplace offer accepted for the BYOL AMI

### AWS Authentication

This project does **not** use `access_key` / `secret_key` variables. The AWS provider resolves credentials in this order:

1. **`aws_profile`** -- named profile from `~/.aws/config` (local SSO runs)
2. **`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`** -- environment variables (GitHub Actions OIDC)
3. **EC2 instance role** -- when running from an EC2 instance

Leave `aws_profile` empty in CI so environment credentials are used.

Input your AWS user created role into your local machine.
```bash 
aws configure
```
- AWS Access Key ID [None]: 
- AWS Secret Access Key [None]: 
- Default region name [None]: us-east-1
- Default output format [None]: table

### Accept Marketplace Terms

Before deploying, accept the AWS Marketplace terms for the BIG-IP BYOL AMI. This is a one-time step per AWS account:

1. Visit the [F5 BIG-IP VE - ALL (BYOL, 2 Boot Locations)](https://aws.amazon.com/marketplace) listing in the AWS Marketplace console
2. Click **Continue to Subscribe** and accept the terms

Confirm available AMIs in your region:

```bash
aws ec2 describe-images --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17.5*BYOL*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --region us-east-1 --output table
```


## Project Structure

```
Single-NIC/
+-- main.tf                         # Root module: public IP lookup, module calls
+-- variables.tf                    # All root-level input variables
+-- outputs.tf                      # SSH, WebUI, EC2 console link, AMI info
+-- providers.tf                    # Provider config (aws ~>5.0, http ~>3.0, time ~>0.9)
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
            +-- f5-declarative-onboarding-*.noarch.rpm
            +-- f5-appsvcs-*.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   ```bash
   cp terraform.tfvars.boilerplate terraform.tfvars
   ```

   Edit `terraform.tfvars` and fill in all required values (see [Variables](#variables) below). The `byol_license` variable is **required** -- provide your F5 registration key.

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


### Global

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Grouping label stamped on every resource via `default_tags` | `bigip-aws-1nic` |
| `resourceOwner` | Owner name for tagging | -- |
| `ownerEmail` | Owner email address for tagging | -- |
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

> **Note**: The deployer's current public IP is automatically detected and appended to the management allowlist.

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
| `f5_ami_search_name` | Wildcard match for the BIG-IP AMI name | `*BIGIP-17*BYOL*` |
| `f5_ami_owner` | AMI owner filter | `aws-marketplace` |
| `byol_license` | F5 BIG-IP BYOL registration key (sensitive, **required**) | -- |
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
| EC2 Instance | F5 BIG-IP VE (BYOL, all modules, IMDSv2 required) |
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
   - **Applies BYOL license** via the `myLicense` class (`licenseType: regKey`)
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions modules: LTM, ASM, AVR, APM, GTM (Best tier)
   - Enables UI advisory banner
7. **Installs AS3** extension (ready for declarations)

### BYOL License Application

The `byol_license` variable is passed into the onboarding template and applied via the DO `myLicense` class:

```yaml
myLicense:
  class: License
  licenseType: regKey
  regKey: '<your-registration-key>'
```

The license is applied during the DO phase of onboarding. If the key is invalid or already in use, the DO declaration will fail -- check the onboarding log at `/var/log/cloud/startup-script.log`.

### RPM Delivery: S3 + IAM Role

Unlike the Azure projects which use blob storage with managed identity or SAS tokens, this project:

- Uploads the DO and AS3 RPMs from `modules/bigip/rpm_files/` to a **private S3 bucket** at apply time
- Grants the BIG-IP's **IAM instance profile** read-only access (`s3:GetObject`) scoped to the two RPM objects
- The onboarding script uses a built-in Python helper (`s3_download.py`) that handles **IMDSv2 token retrieval** and **SigV4 request signing** using only Python stdlib


## Key Differences from PAYG Single-NIC

| Feature | PAYG Single-NIC | BYOL Single-NIC |
|---------|-----------------|------------------|
| AMI search | `*BIGIP-17*PAYG-Best Plus 25Mbps*` | `*BIGIP-17*BYOL*` |
| License | Included in AMI (hourly metered) | `byol_license` variable (F5 registration key, required) |
| DO declaration | No `myLicense` block | `myLicense` class with `licenseType: regKey` |
| Throughput | Baked into AMI (25 Mbps cap) | Determined by license key |
| Template variable | -- | `license` passed to `f5_onboard.tmpl` |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials, passwords, and the BYOL license key.
- **No static AWS keys**: authentication uses SSO profiles or environment credentials, never `access_key`/`secret_key` variables.
- The `byol_license` variable is marked **sensitive** -- Terraform will not display it in plan or apply output.
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
>
> **BYOL licenses** are not automatically revoked on destroy. If you plan to reuse the registration key, revoke it from the F5 licensing portal before or after destroying the infrastructure.
