# F5 BIG-IP Multi-NIC (PAYG) - AWS

This Terraform project deploys a standalone F5 BIG-IP Virtual Edition (VE) in a **multi-NIC (3-NIC) topology** on Amazon Web Services using **Pay-As-You-Go (PAYG)** licensing. Three network interfaces separate management, external (data-plane), and internal (server-side) traffic into dedicated subnets with independent security groups. The BIG-IP is fully onboarded at boot time via F5 BIG-IP Runtime Init and Declarative Onboarding (DO) -- no manual configuration required.

## Architecture

```
                      Internet
                         |
            +------------+------------+
            |                         |
            v                         v
   [ Mgmt Elastic IP ]      [ External Elastic IP ]
   (admin SSH + TMUI)        (virtual-server traffic)
            |                         |
            v                         v
  [ Mgmt Security Group ]   [ External Security Group ]
  Ports: 22, 443             Ports: 80, 443, 8080, 8081
  Source: admin IPs only     Source: RE traffic IPs
            |                         |
            v                         v
    +-------+---------+-------+-------+---------+
    |       eth0 (mgmt)       | eth1 (1.1)      |
    |   Mgmt Subnet           | External Subnet |
    |   e.g. 10.245.1.0/24    | e.g. 10.245.10.0/24
    |                         |                  |
    |        BIG-IP VE (3-NIC, PAYG Best)        |
    |                         |                  |
    |       Modules: LTM, ASM, AVR, APM, GTM    |
    |                         |                  |
    |                         | eth2 (1.2)       |
    |                         | Internal Subnet  |
    |                         | e.g. 10.245.20.0/24
    +---------+---------------+---------+--------+
              |                         |
              v                         v
    [ Internal Security Group ]   Pool members /
    All VPC traffic allowed       backend servers
              |
              v
         AWS VPC (e.g. 10.245.0.0/16)
```

### Traffic Flow

1. Administrators connect to the **management EIP** on port **22** (SSH) or port **443** (TMUI)
2. External clients connect to the **external EIP** for virtual-server traffic on ports 80, 443, 8080, 8081
3. BIG-IP forwards traffic to backend pool members via the **internal interface** (eth2 / 1.2)
4. The TMM default route points to the **external subnet gateway** (`external_gw`)
5. Management traffic is isolated from data-plane traffic on separate interfaces and security groups

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- An AWS account with IAM credentials (IAM Identity Center profile, `~/.aws/credentials`, or OIDC)
- An SSH key pair (public key path provided via `ssh_publickey`)
- F5 BIG-IP AWS Marketplace terms accepted for the PAYG Best Plus 25Mbps offer
- Azure Service Principal credentials (for cross-cloud dependencies such as DNS and Key Vault)

### Accept AWS Marketplace Terms

Before deploying, accept the AWS Marketplace offer for the BIG-IP PAYG image. Navigate to the [AWS Marketplace](https://aws.amazon.com/marketplace) and search for **F5 BIG-IP PAYG Best Plus 25Mbps**, then subscribe. Skip this and the apply fails with `OptInRequired` at instance creation.

Verify the AMI resolves in your target region:

```bash
aws ec2 describe-images --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17*PAYG-Best Plus 25Mbps*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table
```

## Project Structure

```
Multi-NIC/
├── main.tf                         # Root module: public IP lookup, module calls
├── variables.tf                    # All root-level input variables
├── outputs.tf                      # SSH, WebUI, VIP, console URL, per-NIC IPs
├── providers.tf                    # Provider configuration (aws ~>5.0, http ~>3.0, time ~>0.9)
├── terraform.tfvars                # Your variable values (do not commit)
└── modules/
    ├── aws-vpc/
    │   ├── main.tf                 # VPC, 3 subnets, IGW, route table + associations
    │   ├── variables.tf
    │   └── outputs.tf
    └── bigip/
        ├── bigip.tf                # EC2 instance, ENI attachments (external + internal)
        ├── network.tf              # AMI lookup, 3 security groups, 2 ENIs, key pair, 2 EIPs
        ├── s3.tf                   # S3 bucket, RPM objects, IAM role + instance profile
        ├── variables.tf
        ├── bigip_outputs.tf
        ├── f5_onboard.tmpl         # Cloud-init onboarding script template
        └── rpm_files/
            ├── f5-declarative-onboarding-1.49.0-14.noarch.rpm
            └── f5-appsvcs-3.57.0-13.noarch.rpm
```

## Quick Start

1. **Copy and configure variables**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
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
   - **SSH**: `ssh admin@<mgmt_eip>`
   - **WebUI**: `https://<mgmt_eip>` (port 443 -- dedicated management NIC)
   - **External VIP**: `https://<external_eip>`
   - **EC2 Console**: Direct link to the instance in the AWS Console

4. **Monitor onboarding progress**

   ```bash
   ssh -t admin@<mgmt_eip> 'run util bash -c "tail -f /var/log/cloud/startup-script.log"'
   ```

## Variables

### AWS Credentials

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region to deploy into (e.g. `us-east-1`) | -- |
| `aws_profile` | Named profile from `~/.aws/config`; leave empty for OIDC | `""` |

### Azure Credentials (Cross-Cloud)

| Variable | Description | Required |
|----------|-------------|----------|
| `client_id` | Azure Service Principal Application ID | Yes |
| `client_secret` | Azure Service Principal Secret | Yes |
| `tenant_id` | Azure AD Tenant ID | Yes |
| `subscription_id` | Azure Subscription ID | Yes |

### Global

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Grouping label stamped onto every resource via default_tags | `bigip-aws-3nic` |
| `resourceOwner` | Owner name for tagging and audit | -- |
| `instance_size` | EC2 instance type ([sizing guide](https://clouddocs.f5.com/cloud/public/v1/matrix.html#amazon-web-services)) | -- |

### Networking (VPC)

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_name` | VPC name | -- |
| `vpc_cidr` | VPC CIDR block | -- |
| `mgmt_subnet_name` | Management subnet name | -- |
| `mgmt_cidr` | Management subnet CIDR | -- |
| `external_subnet_name` | External subnet name | -- |
| `external_cidr` | External subnet CIDR | -- |
| `internal_subnet_name` | Internal subnet name | -- |
| `internal_cidr` | Internal subnet CIDR | -- |
| `availability_zone` | Full AZ name (e.g. `us-east-1a`) | -- |
| `external_gw` | Default gateway for external subnet (first usable IP in CIDR, e.g. `10.245.10.1`). Becomes the TMM default route. | -- |

### Access Control

| Variable | Description | Default |
|----------|-------------|---------|
| `vpnMgmtSrcAddr` | List of IPs/CIDRs allowed management access (SSH, TMUI) | -- |
| `REtrafficSrcAddr` | List of IPs/CIDRs for application traffic to virtual servers | -- |

> **Note**: The deployer's current public IP is automatically detected and added to the management allowlist.

### BIG-IP VM

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | EC2 instance name tag | -- |
| `instance_prefix` | Prefix for derived resource names (SGs, EIPs, keys, etc.) | -- |

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
| `ntp_server` | Primary NTP server | -- |
| `timezone` | System timezone (Olson format) | `UTC` |
| `script_name` | Onboarding template name (without `.tmpl`) | `f5_onboard` |
| `INIT_URL` | F5 BIG-IP Runtime Init download URL | v2.0.3 |

## Outputs

| Output | Description |
|--------|-------------|
| `BIG-IP-SSH` | Ready-to-use SSH command: `ssh admin@<mgmt_eip>` |
| `BIG-IP-UI-ip` | BIG-IP management URL: `https://<mgmt_eip>` |
| `BIG-IP-External-VIP` | External virtual-server URL: `https://<external_eip>` |
| `ec2_console_url` | Direct link to the EC2 instance in the AWS Console |
| `bigip_ami` | AMI name and ID used for the deployment |
| `onboarding_log_tail` | SSH command to tail the onboarding log |
| `console_output_cmd` | AWS CLI command to retrieve serial console output |
| `management_private_ip` | Management interface private IP |
| `external_public_ip` | External interface Elastic IP |
| `external_private_ip` | External interface private IP (ENI) |
| `internal_private_ip` | Internal interface private IP (ENI) |

## AWS Resources Created

| Resource | Purpose |
|----------|---------|
| VPC | Network backbone with DNS support enabled |
| Subnet (mgmt) | Management interface -- SSH and TMUI access |
| Subnet (external) | External data-plane interface -- virtual-server traffic |
| Subnet (internal) | Internal server-side interface -- pool-member traffic |
| Internet Gateway | Public internet access for all three subnets |
| Route Table + Associations (x3) | Public route table shared by all subnets |
| Security Group (mgmt) | Inbound rules for ports 22, 443 from admin source IPs |
| Security Group (external) | Inbound rules for ports 80, 443, 8080, 8081 from RE traffic sources |
| Security Group (internal) | All inbound traffic from VPC CIDR |
| Network Interface (external) | ENI for external subnet (`source_dest_check = false`) |
| Network Interface (internal) | ENI for internal subnet (`source_dest_check = false`) |
| Elastic IP (mgmt) | Static public IP for management access |
| Elastic IP (external) | Static public IP for virtual-server traffic |
| EC2 Instance | F5 BIG-IP VE (PAYG Best Plus 25Mbps) |
| Key Pair | SSH key pair for instance access |
| S3 Bucket | Hosts DO and AS3 extension RPMs (encrypted, private) |
| S3 Objects (x2) | Declarative Onboarding and AS3 RPM files |
| IAM Role | Allows EC2 to assume role for S3 access |
| IAM Role Policy | Grants `s3:GetObject` on the RPM objects only |
| IAM Instance Profile | Attaches IAM role to the BIG-IP instance |

## Automated Onboarding

The BIG-IP is fully configured at first boot via the `f5_onboard.tmpl` cloud-init script:

1. **Sets passwords** for root and admin accounts
2. **Downloads F5 extensions** (DO and AS3 RPMs) from S3 using IMDSv2 credentials and SigV4-signed requests (inline Python script -- no AWS CLI or boto3 required)
3. **Installs F5 BIG-IP Runtime Init**
4. **Applies Declarative Onboarding (DO)** configuration:
   - Sets system hostname
   - Creates two admin users with SSH key access
   - Hardens HTTPD (disables SSLv2, SSLv3, TLSv1)
   - Configures DNS and NTP
   - Provisions modules: LTM, ASM, AVR, APM, GTM (Best tier)
   - Enables UI advisory banner
   - Creates `external_vlan` (interface 1.1, tag 4094) and `internal_vlan` (interface 1.2, tag 4093)
   - Creates `external_self` Self-IP with the external ENI's private IP
   - Creates `internal_self` Self-IP with the internal ENI's private IP
   - Configures TMM default route via `external_gw` (external subnet gateway)

## Key Differences from Single-NIC

| Feature | Single-NIC | Multi-NIC (this project) |
|---------|-----------|--------------------------|
| Network interfaces | 1 (shared mgmt + data) | 3 (mgmt, external, internal) |
| Management GUI port | 8443 (shared NIC) | 443 (dedicated mgmt NIC) |
| Security groups | 1 combined | 3 separate (mgmt, external, internal) |
| Elastic IPs | 1 | 2 (mgmt + external) |
| DO VLANs / Self-IPs | None | external_vlan (1.1) + internal_vlan (1.2) with Self-IPs |
| TMM default route | Inherited from OS | Explicit route via `external_gw` |
| ENI source/dest check | N/A | Disabled on external and internal (data-plane) |

## Security Notes

- **Do not commit `terraform.tfvars`** to version control -- it contains credentials and passwords.
- Management access is restricted to specific source IPs via the management security group.
- External and internal security groups enforce least-privilege inbound rules.
- HTTPD is hardened with strong TLS cipher suites (SSLv2, SSLv3, and TLSv1 are disabled).
- RPM downloads use the BIG-IP instance's **IAM instance profile** with a scoped S3 read policy (no shared keys or SAS tokens).
- The S3 bucket has **public access blocked** and **server-side encryption** (AES256) enabled.
- IMDSv2 is enforced (`http_tokens = "required"`) -- the onboarding template uses static values and never calls the metadata service over plain HTTP.
- The root EBS volume is **encrypted by default**.
- `source_dest_check` is disabled only on data-plane interfaces (external, internal), not on management.

## Cleanup

```bash
terraform destroy
```

Or terminate the instance and delete the VPC directly from the AWS Console using the link provided in the `ec2_console_url` output.
