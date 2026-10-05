# F5 Distributed Cloud - Web Application & API Protection (WaaP)

Terraform configuration for deploying an **Application Firewall** (WAF) policy on [F5 Distributed Cloud](https://www.f5.com/cloud) (XC). This project provisions a `volterra_app_firewall` resource with full control over enforcement mode, bot detection, attack signatures, AI enhancements, and violation-level tuning.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- An F5 Distributed Cloud tenant with API access
- A `.p12` API credential file generated from your F5 XC console (Administered Settings > Credentials)

## Project Structure

```
WaaP/
  main.tf             # Provider config and the app firewall resource
  variables.tf        # All variable declarations with defaults and validation
  terraform.tfvars    # Your deployment-specific variable values
  <your>-api-cert.p12 # Your F5 XC API credential (not checked into version control)
```

## Quick Start

1. **Clone the repository** and navigate to this directory.

2. **Obtain your API credential.** In the F5 XC Console, go to **Administration > Personal Management > Credentials** and generate a `.p12` API certificate. Place it in this directory.

3. **Configure `terraform.tfvars`.** At minimum, set the four required variables:

   ```hcl
   app_fw_name      = "my-app-firewall"
   xc_namespace = "my-namespace"
   xc_api_url       = "https://<your-tenant>.console.ves.volterra.io/api"
   xc_api_creds     = "<your>-api-cert.p12"
   ```

4. **Initialize and apply:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Required Variables

| Variable | Type | Description |
|---|---|---|
| `app_fw_name` | `string` | Name of the App Firewall resource |
| `xc_namespace` | `string` | Namespace in which to create the App Firewall |
| `xc_api_url` | `string` | F5 XC tenant API URL (e.g. `https://<tenant>.console.ves.volterra.io/api`) |
| `xc_api_creds` | `string` | Filename of the `.p12` credential file (must be in the project directory) |

## Configuration Options

The firewall policy is organized into six configuration groups. Each group requires exactly one option to be active. All groups have sensible defaults, so you only need to override what you want to customize.

---

### 1. Response Codes

Controls which HTTP response codes the WAF allows through.

| Variable | Type | Default | Description |
|---|---|---|---|
| `allow_all_response_codes` | `bool` | `true` | Allow all response codes |
| `allowed_response_codes` | `list(number)` | `[200, 201, 204, 301, 302]` | Specific codes to allow (only used when `allow_all_response_codes = false`) |

---

### 2. Anonymization

Controls whether sensitive data (cookies, headers, query params) is masked in logs.

| Variable | Type | Default | Description |
|---|---|---|---|
| `anonymization_mode` | `string` | `"default"` | `"default"`, `"disabled"`, or `"custom"` |
| `custom_anonymization_configs` | `list(object)` | `[]` | Items to anonymize when mode is `"custom"` |

Each item in `custom_anonymization_configs` can specify one of:
- `cookie_name` -- mask a cookie
- `header_name` -- mask an HTTP header
- `query_param_name` -- mask a query parameter

**Example:**
```hcl
anonymization_mode = "custom"
custom_anonymization_configs = [
  { cookie_name      = "session_id" },
  { header_name      = "Authorization" },
  { query_param_name = "api_key" }
]
```

---

### 3. Enforcement Mode

| Variable | Type | Default | Description |
|---|---|---|---|
| `enforcement_mode` | `string` | `"blocking"` | `"blocking"` (actively block threats) or `"monitoring"` (log only, no blocking) |

---

### 4. Blocking Page

| Variable | Type | Default | Description |
|---|---|---|---|
| `use_default_blocking_page` | `bool` | `true` | Use the system default blocking page shown to blocked users |

---

### 5. AI Enhancements

Controls AI-powered threat analysis. When enabled, choose the risk level to mitigate.

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_ai_enhancements` | `bool` | `true` | Enable AI-powered enhancements |
| `ai_mitigate_high_medium_risk_action` | `bool` | `true` | Mitigate both high and medium risk threats |
| `ai_mitigate_high_risk_action` | `bool` | `false` | Mitigate high risk only (used when `ai_mitigate_high_medium_risk_action = false`) |

---

### 6. Detection Settings

Set `use_default_detection_settings = true` to use F5's defaults, or `false` to customize the sub-settings below.

| Variable | Type | Default | Description |
|---|---|---|---|
| `use_default_detection_settings` | `bool` | `false` | `true` = use system defaults, `false` = customize below |

#### 6a. Bot Detection

| Variable | Type | Default | Description |
|---|---|---|---|
| `bot_setting_mode` | `string` | `"default"` | `"default"` or `"custom"` |
| `good_bot_action` | `string` | `"IGNORE"` | Action for good bots: `BLOCK`, `IGNORE`, or `REPORT` |
| `malicious_bot_action` | `string` | `"BLOCK"` | Action for malicious bots: `BLOCK`, `IGNORE`, or `REPORT` |
| `suspicious_bot_action` | `string` | `"BLOCK"` | Action for suspicious bots: `BLOCK`, `IGNORE`, or `REPORT` |

#### 6b. Attack Signature Staging

| Variable | Type | Default | Description |
|---|---|---|---|
| `staging_mode` | `string` | `"disabled"` | `"disabled"`, `"stage_new_and_updated"`, or `"stage_new_only"` |
| `staging_period_days` | `number` | `7` | Number of days signatures remain in staging |

#### 6c. Threat Campaigns

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_threat_campaigns` | `bool` | `true` | Enable threat campaign protection |

#### 6d. Automatic Signature Tuning (Suppression)

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_suppression` | `bool` | `true` | Enable automatic attack signature tuning |

#### 6e. Attack Types

| Variable | Type | Default | Description |
|---|---|---|---|
| `use_default_attack_types` | `bool` | `true` | Use default attack type settings |
| `disabled_attack_types` | `list(string)` | `[]` | Attack types to disable (e.g. `["ATTACK_TYPE_SQL_INJECTION"]`) |

#### 6f. Signature Accuracy

| Variable | Type | Default | Description |
|---|---|---|---|
| `accuracy_signature_selection` | `string` | `"high_medium_low"` | `"high_medium_low"`, `"high_medium"`, or `"only_high"` |

#### 6g. Violations

Override the enabled/disabled state of individual violation types. Pass a list of violation objects to `violations_list`. Each object has:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | Yes | Violation type enum (e.g. `VIOL_METHOD`) |
| `enabled` | `bool` | No | Enable or disable this violation |
| `enabled_by_default` | `string` | No | Whether this violation is enabled by default (`"Yes"` / `"No"`) |
| `title` | `string` | No | Human-readable title |
| `description` | `string` | No | Description of what the violation detects |

See `terraform.tfvars` for the full default violations list with all 27 violation types.

## Example: Minimal Configuration

```hcl
# terraform.tfvars - Accept all defaults, just set required values
app_fw_name      = "my-waf"
xc_namespace     = "my-namespace"
xc_api_url       = "https://my-tenant.console.ves.volterra.io/api"
xc_api_creds     = "my-api-cert.p12"
```

## Example: Custom Configuration

```hcl
# terraform.tfvars - Customized deployment
app_fw_name      = "prod-waf"
xc_namespace     = "production"
xc_api_url       = "https://my-tenant.console.ves.volterra.io/api"
xc_api_creds     = "my-api-cert.p12"

enforcement_mode         = "blocking"
allow_all_response_codes = false
allowed_response_codes   = [200, 201, 301, 302, 400, 401, 403, 404, 503]

enable_ai_enhancements              = true
ai_mitigate_high_medium_risk_action = true

use_default_detection_settings = false
bot_setting_mode               = "custom"
good_bot_action                = "IGNORE"
suspicious_bot_action          = "REPORT"
malicious_bot_action           = "BLOCK"

enable_threat_campaigns = true
enable_suppression      = true
```

## Cleanup

To remove the firewall policy:

```bash
terraform destroy
```

## Security Notes

- **Do not commit your `.p12` credential file to version control.** Add `*.p12` to your `.gitignore`.
- Terraform state may contain sensitive values. Consider using a [remote backend](https://developer.hashicorp.com/terraform/language/backend) with encryption for production use.
