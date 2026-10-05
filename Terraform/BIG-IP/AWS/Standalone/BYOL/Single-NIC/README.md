# AWS Single-NIC BIG-IP

Single-NIC BIG-IP VE in AWS. 

```
providers.tf   aws + azurerm, http, time
main.tf        module wiring, my_ip
variables.tf
outputs.tf
terraform.tfvars.boilerplate
modules/
  aws-vpc/     vpc, subnet, igw, route table, association
  bigip/       ami lookup, sg, key pair, eip, instance, f5_onboard.tmpl
```

---

## Before your first apply

### 1. Accept the AWS Marketplace offer

**This is not a Terraform step and it is not optional.** Someone with
marketplace rights has to accept the offer for the BIG-IP AMI in the AWS
Marketplace console, once per account. It is the analog of
`az vm image terms accept` / the Azure `plan` block.

Skip it and the apply fails with `OptInRequired` at instance creation — after
the VPC, subnet, gateway, security group and EIP have all been built.

### 2. Confirm the AMI name in your region

`f5_ami_search_name` defaults to `*BIGIP-17*PAYG-Best Plus 25Mbps*`, matching
the Azure labs' `f5-big-best-plus-hourly-25mbps`. Verify it resolves:

```bash
aws ec2 describe-images --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17*PAYG*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table
```

In order to use the`f5_ami_search_name` for a versin 21image, use the following. `*BIGIP-21*PAYG-Best Plus 25Mbps*`. Verify it resolves:

```bash
aws ec2 describe-images --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-21*PAYG*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table
```

Keep the patch level wildcarded. F5 deprecates and removes older AMIs, so a
hard-pinned `17.1.1-0.0.4` will break a plan that worked last month.

### 3. Set up credentials

No `access_key` / `secret_key` variables exist in this project — the provider
resolves credentials itself. Locally that means an IAM Identity Center
profile. Create `~/.aws/config` (you do not currently have one):

```ini
[sso-session f5]
sso_start_url           = https://<your-f5-portal>.awsapps.com/start
sso_region              = us-east-1
sso_registration_scopes = sso:account:access

[profile bigip-lab]
sso_session             = f5
sso_account_id          = 123456789012
sso_role_name           = <PermissionSetName>
region                  = us-east-1
```

```bash
aws sso login --profile bigip-lab
aws sts get-caller-identity --profile bigip-lab
```

Then set `aws_profile = "bigip-lab"` in `terraform.tfvars`.

IAM permissions: `PowerUserAccess` is the closest analog to the Contributor
role the Azure service principal uses. It excludes IAM, which is fine here —
nothing in this project creates a role or instance profile.

### 4. Everything else

```bash
cp terraform.tfvars.boilerplate terraform.tfvars
# fill it in, then
terraform init && terraform plan
```

`../../modules/artifact-lookup` resolves the shared artifact store by name, so
`BIG-IP Projects/artifact-store` must be applied before this project can plan.

---

## Cross-cloud dependencies

Three things stayed in Azure. This is a considered choice for a first AWS
deployment, not an oversight: it keeps the variable under test to "does BIG-IP
come up in EC2" rather than changing five things at once.

| Dependency | Where it is | Why it stayed |
|---|---|---|
| `kulland.info` DNS zone | Azure DNS | The zone already exists and an A record pointing at an Elastic IP works the same from anywhere. Migrating means delegating a subzone to Route 53. |
| Wildcard cert | Azure Key Vault | Moving to Secrets Manager also means giving the instance an IAM instance profile and reworking the runtime-init parameters. |
| DO / AS3 / CrowdStrike artifacts | Azure blob storage | Fetched over HTTPS with a SAS token. Works identically from EC2 — `modules/artifact-lookup` is reused completely unchanged. |

So the Azure service principal is still required in `terraform.tfvars`. The DNS
record is named `bigip-1nic-aws` rather than the Azure project's `bigip-1nic`,
because both would otherwise overwrite the same name in the shared zone.

---

## What changed from the Azure project

### Structural

| Azure | Here |
|---|---|
| `azurerm_resource_group` | **Nothing.** AWS has no resource group. `project_name` + provider `default_tags` replace it as the grouping label, and there is no "delete the RG" escape hatch — teardown is entirely Terraform state. |
| `azurerm_virtual_network` + `azurerm_subnet` | `aws_vpc` + `aws_subnet` **+ `aws_internet_gateway` + `aws_route_table` + `aws_route_table_association`** |
| `azurerm_network_security_group` | `aws_security_group` — no priorities, stateful, and **egress is deny-all by default** |
| `azurerm_public_ip` + `azurerm_network_interface` | `aws_eip` + `aws_eip_association` |
| `azurerm_storage_account` (boot diagnostics) | Dropped. `aws ec2 get-console-output` is free and built in — see the `console_output_cmd` output. |
| `source_image_reference` + `plan` | `data "aws_ami"` + a manual Marketplace subscription |
| `client_id`/`client_secret`/`tenant_id`/`subscription_id` | `aws_region` + `aws_profile`. The account is implied by the credential; there is no subscription ID. |
| `availability_zone = 1` | `availability_zone = "us-east-1a"` — AZ-scoped, immutable, pins the subnet |
| `Standard_DS4_v2` | `m5.2xlarge` (8 vCPU / 32 GiB vs 8 / 28) |

### Onboarding template

`modules/bigip/f5_onboard.tmpl` is the Azure template with three changes. The
DO declaration, both users, the httpd cipher list, the AS3 cert/TLS_Server and
the entire CrowdStrike block are untouched.

1. `runtime-init --cloud azure` → `--cloud aws`
2. `HOST_NAME` is now a static value from `bigip-hostname` instead of an Azure
   metadata lookup. AWS's compute name is the internal DNS name
   (`ip-10-245-1-23`), which is not a hostname you want on a BIG-IP. This also
   means `bigip-hostname` is finally wired up — the Azure projects declare it
   but the template overrides it.
3. `REGION` is a static value from `aws_region` instead of an IMDS `type: url`
   fetch. IMDSv2 requires a PUT to mint a token before any metadata GET, and
   runtime-init's `type: url` parameter only issues a plain GET. Passing the
   value in from Terraform means the instance can keep
   `http_tokens = "required"` instead of re-enabling IMDSv1.

One bug fixed in passing: the Azure modules pass `var.ssh_publickey` — a
*path* — into the template, so DO sets the literal string `~/.ssh/id_rsa.pub`
as both users' authorized key. Here it is `trimspace(file(var.ssh_publickey))`.
Worth fixing in the Azure projects too.

---

## CrowdStrike toggle

`crowdstrike_enabled` (default `true`) drives the sensor from one place in
`terraform.tfvars`. It fans out to both consumers — `module "artifacts"`, which
decides whether the sensor blobs are resolved and a SAS minted, and the `bigip`
module, which gates the install block in the onboarding template.

Off is a genuine opt-out rather than a runtime skip:

- no CrowdStrike blob lookups, so no SAS token written into this project's state
- the install block is removed from the rendered `user_data` by a `templatefile`
  `if` directive, so the SAS-signed URLs and the CID never reach an instance
  attribute readable via `ec2:DescribeInstanceAttribute`
- `cs_cid`, `cs_tags_bigip` and `cs_provisioning_token` can all stay empty
- a one-line "install skipped" note still lands in the startup log, so a device
  with no sensor reads as deliberate

It defaults to `true` on purpose — a security sensor that quietly fails to
install is worse than an apply that stops to ask for a CID. Turning it on with
an empty `cs_cid`, or on in one module but not the other, fails at plan time on
a precondition attached to `aws_instance.bigip` rather than twenty minutes into
cloud-init.

---

## Gotchas

**Onboarding fails silently when the VPC has no egress.** This is the one that
will cost you an afternoon. Without the internet gateway, the default route, or
the security group's egress rule, the BIG-IP boots fine and answers on 8443 —
but `f5-bigip-runtime-init` can never reach GitHub, so DO and AS3 never install
and the device comes up bare. There is no error anywhere in the Terraform
output. Check:

```bash
terraform output -raw onboarding_log_tail   # then run it
```

**The GUI is on 8443, not 443.** On single-NIC, httpd cedes 443 to tmm so
virtual servers can use it. Same as the Azure single-NIC projects.

**Don't add VLANs or self-IPs to the DO declaration.** Management and data
plane share eth0. `source_dest_check = false` on the instance is what lets that
interface forward and SNAT traffic for addresses that are not its own.

**PAYG throughput is baked into the AMI.** A 25 Mbps image caps at 25 Mbps
regardless of instance type.

**Editing `f5_onboard.tmpl` rebuilds the instance.** `user_data_replace_on_change
= true` is set deliberately: the AWS provider would otherwise update the
attribute in place on a running instance, where user_data is only ever read at
first boot — making a template edit a silent no-op.

**AMI upgrades need an explicit push.** `lifecycle { ignore_changes = [ami] }`
stops `most_recent = true` from proposing an instance replacement every time F5
publishes a release. To actually move versions:

```bash
terraform apply -replace='module.bigip.aws_instance.bigip'
```

---

## Not included

- **GitHub Actions workflow.** The Azure projects each have one in
  `.github/workflows/`. For AWS, replace the `azure/login@v2` step with OIDC —
  `aws-actions/configure-aws-credentials@v4` with `role-to-assume`, plus
  `permissions: id-token: write` — and leave `aws_profile` empty so the
  environment credentials win. Power-off/on becomes
  `aws ec2 stop-instances` / `start-instances`. One-time setup: an IAM OIDC
  provider for `token.actions.githubusercontent.com` and a role whose trust
  policy restricts `sub` to this repo. No repo secret needed, unlike the Azure
  service principal.
- **Ubuntu app servers.** The `Single-NIC-with-apps` and multi-NIC equivalents
  of `modules/ubuntu` / `modules/internal-app`.
- **Multi-NIC.** Adding interfaces on AWS means explicit `aws_network_interface`
  resources plus an `aws_network_interface_attachment` per extra NIC, and the DO
  declaration then does need VLANs and self-IPs.
