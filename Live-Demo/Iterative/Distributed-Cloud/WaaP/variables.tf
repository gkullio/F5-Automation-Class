variable "xc_api_creds" {
  type        = string
  description = "location of the .p12 credential file"
} 

variable "xc_api_url" {
  type        = string  
  description = "F5 Distributed Cloud tenant API URL."
}

variable "app_fw_name" {
  type        = string
  description = "Name of the App Firewall resource."
}

variable "xc_namespace" {
  type        = string
  description = "Namespace in which to create the App Firewall."
}

# --- Response Code Options ---
variable "allow_all_response_codes" {
  type        = bool
  description = "Allow all response codes."
  default     = true
}

variable "allowed_response_codes" {
  type        = list(number)
  description = "List of specific allowed response HTTP status codes (used if allow_all_response_codes is false)."
  default     = [200, 201, 204, 301, 302]
}

# --- Anonymization Options ---
variable "anonymization_mode" {
  type        = string
  description = "Anonymization mode: 'default', 'disabled', or 'custom'."
  default     = "default"
  validation {
    condition     = contains(["default", "disabled", "custom"], var.anonymization_mode)
    error_message = "anonymization_mode must be 'default', 'disabled', or 'custom'."
  }
}
variable "custom_anonymization_configs" {
  type = list(object({
    cookie_name      = optional(string, null)
    header_name      = optional(string, null)
    query_param_name = optional(string, null)
  }))
  description = "List of items to anonymize when anonymization_mode = 'custom'."
  default     = []
}

# --- Enforcement Mode Options ---
variable "enforcement_mode" {
  type        = string
  description = "Enforcement mode: 'blocking' or 'monitoring'."
  default     = "blocking"

  validation {
    condition     = contains(["blocking", "monitoring"], var.enforcement_mode)
    error_message = "enforcement_mode must be either 'blocking' or 'monitoring'."
  }
}

# --- Blocking Page Options ---
variable "use_default_blocking_page" {
  type        = bool
  description = "Use system default blocking page."
  default     = true
}

# --- AI Enhancements Options ---
variable "disable_ai_enhancements" {
  type        = bool
  description = "Disable AI enhancements."
  default     = true
}

# --- Detection Settings Options ---
variable "use_default_detection_settings" {
  type        = bool
  description = "Set to true to use system default detection settings, or false to customize below."
  default     = false
}

variable "detection_default_bot_setting" {
  type        = bool
  description = "Enable default bot setting within detection settings."
  default     = true
}

variable "detection_enable_suppression" {
  type        = bool
  description = "Enable signature suppression."
  default     = true
}

variable "detection_default_attack_type_settings" {
  type        = bool
  description = "Use default attack type settings."
  default     = true
}

variable "detection_high_medium_low_accuracy_signatures" {
  type        = bool
  description = "Enable signatures across High, Medium, and Low accuracy thresholds."
  default     = true
}

variable "detection_disable_staging" {
  type        = bool
  description = "Disable staging mode for signature updates."
  default     = true
}

variable "detection_enable_threat_campaigns" {
  type        = bool
  description = "Enable threat campaigns protection."
  default     = true
}

# --- AI Enhancements Options ---
variable "enable_ai_enhancements" {
  type        = bool
  description = "Set to true to enable AI enhancements, or false to disable."
  default     = true
}
variable "ai_mitigate_high_medium_risk_action" {
  type        = bool
  description = "Mitigate high and medium risk actions when AI enhancements are enabled."
  default     = true
}
variable "ai_mitigate_high_risk_action" {
  type        = bool
  description = "Mitigate high risk actions only (used if ai_mitigate_high_medium_risk_action is false)."
  default     = false
}

# =========================================================================
# 1. BOT DETECTION SETTINGS
# =========================================================================
variable "bot_setting_mode" {
  type        = string
  description = "Bot setting mode: 'default' or 'custom'."
  default     = "default"
  validation {
    condition     = contains(["default", "custom"], var.bot_setting_mode)
    error_message = "bot_setting_mode must be 'default' or 'custom'."
  }
}
variable "good_bot_action" {
  type        = string
  description = "Action for good bots when bot_setting_mode is 'custom': 'BLOCK', 'IGNORE', or 'REPORT'."
  default     = "IGNORE"
}
variable "malicious_bot_action" {
  type        = string
  description = "Action for malicious bots when bot_setting_mode is 'custom': 'BLOCK', 'IGNORE', or 'REPORT'."
  default     = "BLOCK"
}
variable "suspicious_bot_action" {
  type        = string
  description = "Action for suspicious bots when bot_setting_mode is 'custom': 'BLOCK', 'IGNORE', or 'REPORT'."
  default     = "BLOCK"
}
# =========================================================================
# 2. ATTACK SIGNATURE STAGING
# =========================================================================
variable "staging_mode" {
  type        = string
  description = "Signature staging mode: 'disabled', 'stage_new_and_updated', or 'stage_new_only'."
  default     = "disabled"
  validation {
    condition     = contains(["disabled", "stage_new_and_updated", "stage_new_only"], var.staging_mode)
    error_message = "staging_mode must be 'disabled', 'stage_new_and_updated', or 'stage_new_only'."
  }
}
variable "staging_period_days" {
  type        = number
  description = "Staging period in days when staging is enabled."
  default     = 7
}
# =========================================================================
# 3. THREAT CAMPAIGNS
# =========================================================================
variable "enable_threat_campaigns" {
  type        = bool
  description = "Enable threat campaigns protection."
  default     = true
}
# =========================================================================
# 4. AUTOMATIC ATTACK SIGNATURE TUNING (SUPPRESSION)
# =========================================================================
variable "enable_suppression" {
  type        = bool
  description = "Enable automatic signature tuning / suppression."
  default     = true
}
# =========================================================================
# 5. ATTACK TYPES
# =========================================================================
variable "use_default_attack_types" {
  type        = bool
  description = "Set to true to use default attack types, or false to specify disabled_attack_types."
  default     = true
}
variable "disabled_attack_types" {
  type        = list(string)
  description = "List of attack types to disable when use_default_attack_types is false."
  default     = []
}
# =========================================================================
# 6. SIGNATURE SELECTION BY ACCURACY
# =========================================================================
variable "accuracy_signature_selection" {
  type        = string
  description = "Signature accuracy filter: 'high_medium_low', 'high_medium', or 'only_high'."
  default     = "high_medium_low"
  validation {
    condition     = contains(["high_medium_low", "high_medium", "only_high"], var.accuracy_signature_selection)
    error_message = "accuracy_signature_selection must be 'high_medium_low', 'high_medium', or 'only_high'."
  }
}



# Optional violations view list
variable "violations_list" {
  type = list(object({
    name               = string # REQUIRED for each violation item
    enabled            = optional(bool, true)
    enabled_by_default = optional(string, null)
    title              = optional(string, null)
    description        = optional(string, null)
  }))
  description = "List of specific violation settings overrides. Leave empty [] if not overriding specific violation types."
  default     = []
}