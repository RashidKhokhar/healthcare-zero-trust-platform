# HIPAA §164.308(a)(6) — Security Incident Procedures: automated threat
# detection with EKS-specific audit log monitoring and malware scanning
# on EBS volumes, routed to a real alerting channel instead of sitting
# unread in a console.

resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}

resource "aws_guardduty_organization_configuration" "this" {
  detector_id = aws_guardduty_detector.this.id
  auto_enable = true

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        auto_enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }
}

resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${var.environment}-guardduty-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.environment}-guardduty-findings"
  description = "Route GuardDuty findings (medium severity+) to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "sns-alert"
  arn       = aws_sns_topic.guardduty_alerts.arn
}
