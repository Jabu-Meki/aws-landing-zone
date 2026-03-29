terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  management_region = "us-east-1"

  organizations_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]

  service_principals = {
    cloudtrail = "cloudtrail.amazonaws.com"
    config     = "config.amazonaws.com"
    guardduty  = "guardduty.amazonaws.com"
  }

  audit_bucket_name = "cental-logs-${aws_organizations_account.audit.id}"
}

provider "aws" {
  region  = local.management_region
  profile = "management"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "config_service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [local.service_principals.config]
    }
  }
}

# Organization
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]

  aws_service_access_principals = local.organizations_service_access_principals
}

# Organizational Units
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Service Control Policies
resource "aws_organizations_policy" "deny_unapproved_regions" {
  name        = "DenyUnapprovedRegions"
  description = "Denies access to all regions except us-east-1, eu-west-1 and af-south-1"
  content     = file("policies/scps/deny_unapproved_regions.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_leaving_org" {
  name        = "PreventLeavingOrganization"
  description = "Prevents member accounts from leaving the organization"
  content     = file("policies/scps/prevent_leaving_org.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_disable_cloudtrail" {
  name        = "PreventDisableCloudTrail"
  description = "Prevents member accounts from disabling CloudTrail"
  content     = file("policies/scps/prevent_disable_cloudtrail.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "enforce_encryption" {
  name        = "EnforceEncryption"
  description = "Enforces encryption for supported services"
  content     = file("policies/scps/enforce_encryption.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "restrict_root_user" {
  name        = "RestrictRootUser"
  description = "Restricts the use of the root user"
  content     = file("policies/scps/restrict_root_user.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_delete_iam_roles" {
  name        = "PreventDeletingIAMRoles"
  description = "Prevents member accounts from deleting IAM Roles"
  content     = file("policies/scps/prevent_delete_iam_roles.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# SCP Attachments
resource "aws_organizations_policy_attachment" "prevent_leaving_org_root" {
  policy_id = aws_organizations_policy.prevent_leaving_org.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "prevent_disable_cloudtrail_root" {
  policy_id = aws_organizations_policy.prevent_disable_cloudtrail.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "prevent_delete_iam_roles_root" {
  policy_id = aws_organizations_policy.prevent_delete_iam_roles.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "restrict_root_user_security" {
  policy_id = aws_organizations_policy.restrict_root_user.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "enforce_encryption_workloads" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Member Accounts
resource "aws_organizations_account" "audit" {
  name      = "AuditAccount"
  email     = "jabulanimeki+audit@outlook.com"
  parent_id = aws_organizations_organizational_unit.security.id

  tags = {
    Purpose = "Central logging and audit storage"
  }
}

resource "aws_organizations_account" "security_tools" {
  name      = "SecurityToolsAccount"
  email     = "jabulanimeki+security@outlook.com"
  parent_id = aws_organizations_organizational_unit.security.id

  tags = {
    Purpose = "GuardDuty Security Hub threat detection"
  }
}

resource "aws_organizations_account" "dev" {
  name      = "DevelopmentAccount"
  email     = "jabulanimeki+dev@outlook.com"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Purpose     = "Development and testing workloads"
    Environment = "dev"
  }
}

resource "aws_organizations_account" "prod" {
  name      = "ProductionAccount"
  email     = "jabulanimeki+prod@outlook.com"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Purpose     = "Production customer workloads"
    Environment = "prod"
  }
}

resource "aws_organizations_policy_attachment" "deny_regions_workloads" {
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id

  depends_on = [
    aws_organizations_organization.main,
    aws_organizations_organizational_unit.workloads,
    aws_organizations_policy.deny_unapproved_regions
  ]
}

# Audit Account Access
provider "aws" {
  alias   = "audit"
  region  = local.management_region
  profile = "management"

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.audit.id}:role/OrganizationAccountAccessRole"
  }
}

# Audit Logging
resource "aws_s3_bucket" "central_logs" {
  provider = aws.audit
  bucket   = local.audit_bucket_name

  force_destroy = true
}

resource "aws_s3_bucket_versioning" "central_logs" {
  provider = aws.audit
  bucket   = aws_s3_bucket.central_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "central_logs" {
  provider = aws.audit
  bucket   = aws_s3_bucket.central_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "central_logs" {
  provider = aws.audit
  bucket   = aws_s3_bucket.central_logs.id
  policy   = data.aws_iam_policy_document.central_logs.json
}

data "aws_iam_policy_document" "central_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.cloudtrail]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.central_logs.arn]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.cloudtrail]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.cloudtrail]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/${aws_organizations_organization.main.id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.config]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.central_logs.arn]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.config]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/*"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.service_principals.guardduty]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/GuardDuty/*"]
  }
}

# Organization CloudTrail
resource "aws_cloudtrail" "organization" {
  name                          = "organization-trail"
  s3_bucket_name                = aws_s3_bucket.central_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = true

  depends_on = [aws_s3_bucket_policy.central_logs]
}

# AWS Config
resource "aws_iam_role" "config" {
  name               = "AWSConfigRole"
  assume_role_policy = data.aws_iam_policy_document.config_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "central-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "central-channel"
  s3_bucket_name = aws_s3_bucket.central_logs.bucket

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_iam_role" "config_aggregator" {
  name               = "AWSConfigAggregatorRole"
  assume_role_policy = data.aws_iam_policy_document.config_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "organization" {
  name = "organization-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator.arn
  }
}
