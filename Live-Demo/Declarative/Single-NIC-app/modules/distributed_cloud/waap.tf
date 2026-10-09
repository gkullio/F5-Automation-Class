resource "volterra_app_firewall" "this" {
  name                                        = var.app_fw_name      # REQUIRED: Name of the AppFirewall resourc
  namespace                                   = var.xc_namespace # REQUIRED: Namespace where the resource is deployed

  # =========================================================================
  # CHOICE GROUP 1: Response Codes (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  allow_all_response_codes                    = var.allow_all_response_codes # Choice option 1

  dynamic "allowed_response_codes" { # Choice option 2
    for_each                                  = var.allow_all_response_codes ? [] : [1]
    content {
      response_code                           = var.allowed_response_codes # REQUIRED if allowed_response_codes block is declared
    }
  }
/*
  # =========================================================================
  # CHOICE GROUP 2: Anonymization (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  default_anonymization                       = var.use_default_anonymization ? true : null # Choice option 1
  disable_anonymization                       = var.disable_anonymization ? true : null     # Choice option 2
*/
# =========================================================================
  # CHOICE GROUP 2: Anonymization (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  default_anonymization                       = var.anonymization_mode == "default" ? true : null  # Choice option 1: Default
  disable_anonymization                       = var.anonymization_mode == "disabled" ? true : null # Choice option 2: Disabled
  dynamic "custom_anonymization" { # Choice option 3: Custom
    for_each                                  = var.anonymization_mode == "custom" ? [1] : []
    content {
      dynamic "anonymization_config" {
        for_each                              = var.custom_anonymization_configs
        content {
          dynamic "cookie" {
            for_each                          = anonymization_config.value.cookie_name != null ? [1] : []
            content {
              cookie_name                     = anonymization_config.value.cookie_name # REQUIRED if cookie block is used
            }
          }
          dynamic "http_header" {
            for_each                          = anonymization_config.value.header_name != null ? [1] : []
            content {
              header_name                     = anonymization_config.value.header_name # REQUIRED if http_header block is used
            }
          }
          dynamic "query_parameter" {
            for_each                          = anonymization_config.value.query_param_name != null ? [1] : []
            content {
              query_param_name                = anonymization_config.value.query_param_name # REQUIRED if query_parameter block is used
            }
          }
        }
      }
    }
  }  
  # =========================================================================
  # CHOICE GROUP 3: Enforcement Mode (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  blocking                                    = var.enforcement_mode == "blocking" ? true : null   # Choice option 1
  monitoring                                  = var.enforcement_mode == "monitoring" ? true : null # Choice option 2

  # =========================================================================
  # CHOICE GROUP 4: Blocking Page (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  use_default_blocking_page                   = var.use_default_blocking_page # Choice option 1

  # =========================================================================
  # CHOICE GROUP 5: AI Enhancements (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  disable_ai_enhancements                     = var.enable_ai_enhancements ? null : true # Choice option 1: Disable AI

  dynamic "enable_ai_enhancements" { # Choice option 2: Enable AI
    for_each                                  = var.enable_ai_enhancements ? [1] : []
    content {
      mitigate_high_medium_risk_action        = var.ai_mitigate_high_medium_risk_action ? true : null
      mitigate_high_risk_action               = var.ai_mitigate_high_medium_risk_action ? null : (var.ai_mitigate_high_risk_action ? true : null)
    }
  }

  # =========================================================================
  # CHOICE GROUP 6: Detection Settings (REQUIRED: Exactly 1 option must be active)
  # =========================================================================
  default_detection_settings                  = var.use_default_detection_settings ? true : null

  dynamic "detection_settings" {
    for_each                                  = var.use_default_detection_settings ? [] : [1]
    content {
      # 1. BOT DETECTION SETTINGS

      default_bot_setting                     = var.bot_setting_mode == "default" ? true : null

      dynamic "bot_protection_setting" {
        for_each                              = var.bot_setting_mode == "custom" ? [1] : []
        content {
          good_bot_action                     = var.good_bot_action
          malicious_bot_action                = var.malicious_bot_action
          suspicious_bot_action               = var.suspicious_bot_action
        }
      }

      # 2. AUTOMATIC ATTACK SIGNATURE TUNING (SUPPRESSION)

      enable_suppression                      = var.enable_suppression ? true : null
      disable_suppression                     = var.enable_suppression ? null : true

      # 3. ATTACK TYPES & 6. SIGNATURE SELECTION BY ACCURACY

      signature_selection_setting {
        default_attack_type_settings          = var.use_default_attack_types ? true : null
        dynamic "attack_type_settings" {
          for_each                            = var.use_default_attack_types ? [] : [1]
          content {
            disabled_attack_types             = var.disabled_attack_types # REQUIRED if attack_type_settings block is used
          }
        }
        high_medium_low_accuracy_signatures   = var.accuracy_signature_selection == "high_medium_low" ? true : null
        high_medium_accuracy_signatures       = var.accuracy_signature_selection == "high_medium" ? true : null
        only_high_accuracy_signatures         = var.accuracy_signature_selection == "only_high" ? true : null
      }
      # 4. ATTACK SIGNATURE STAGING

      disable_staging                         = var.staging_mode == "disabled" ? true : null
      dynamic "stage_new_and_updated_signatures" {
        for_each                              = var.staging_mode == "stage_new_and_updated" ? [1] : []
        content {
          staging_period                      = var.staging_period_days
        }
      }
      dynamic "stage_new_signatures" {
        for_each                              = var.staging_mode == "stage_new_only" ? [1] : []
        content {
          staging_period                      = var.staging_period_days
        }
      }

      # 5. THREAT CAMPAIGNS
      enable_threat_campaigns                 = var.enable_threat_campaigns ? true : null
      disable_threat_campaigns                = var.enable_threat_campaigns ? null : true

    
      # 6. VIOLATIONS VIEW
      dynamic "violations_view" {
        for_each = var.violations_list
        content {
          name                                = violations_view.value.name # REQUIRED if violations_view block is defined (must be a valid AppFirewallViolationType enum string)
          enabled                             = violations_view.value.enabled
          enabled_by_default                  = violations_view.value.enabled_by_default
          title                               = violations_view.value.title
          description                         = violations_view.value.description
        }
      }
    }
  }
}
