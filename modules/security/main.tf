# GuardDuty in Audit Account
resource "aws_guardduty_detector" "audit" {
  provider = aws.audit
  enable   = true
}

# GuardDuty in Workload Account
resource "aws_guardduty_detector" "workload" {
  provider = aws.workload
  enable   = true
}

# AWS Config IAM Role
data "aws_iam_policy_document" "config_service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  provider           = aws.audit
  name               = "AWSConfigRole"
  assume_role_policy = data.aws_iam_policy_document.config_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config" {
  provider   = aws.audit
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role" "config_workload" {
  provider           = aws.workload
  name               = "AWSConfigRole"
  assume_role_policy = data.aws_iam_policy_document.config_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config_workload" {
  provider   = aws.workload
  role       = aws_iam_role.config_workload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# AWS Config Recorder
resource "aws_config_configuration_recorder" "main" {
  provider = aws.audit
  name     = "central-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  provider       = aws.audit
  name           = "central-channel"
  s3_bucket_name = var.log_bucket_name

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  provider   = aws.audit
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_configuration_recorder" "workload" {
  provider = aws.workload
  name     = "workload-recorder"
  role_arn = aws_iam_role.config_workload.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "workload" {
  provider       = aws.workload
  name           = "workload-channel"
  s3_bucket_name = var.log_bucket_name

  depends_on = [aws_config_configuration_recorder.workload]
}

resource "aws_config_configuration_recorder_status" "workload" {
  provider   = aws.workload
  name       = aws_config_configuration_recorder.workload.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.workload]
}

resource "aws_iam_role" "config_aggregator" {
  provider           = aws.audit
  name               = "AWSConfigAggregatorRole"
  assume_role_policy = data.aws_iam_policy_document.config_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  provider   = aws.audit
  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "organization" {
  provider = aws.audit
  name     = "organization-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator.arn
  }
}

resource "aws_config_config_rule" "audit_root_mfa" {
  provider = aws.audit
  name     = "root-account-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "audit_s3_public_read" {
  provider = aws.audit
  name     = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "audit_iam_password_policy" {
  provider = aws.audit
  name     = "iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "workload_root_mfa" {
  provider = aws.workload
  name     = "root-account-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.workload]
}

resource "aws_config_config_rule" "workload_s3_public_read" {
  provider = aws.workload
  name     = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.workload]
}

resource "aws_config_config_rule" "workload_iam_password_policy" {
  provider = aws.workload
  name     = "iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  depends_on = [aws_config_configuration_recorder_status.workload]
}
