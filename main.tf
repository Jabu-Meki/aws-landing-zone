terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "management"
}

resource "aws_organizations_organization" "main" {
  feature_set = "ALL"
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]
}



# ORGANIZATION UNITS (OUs)
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

# SCP 1: Deny access to unapproved regions
resource "aws_organizations_policy" "deny_unapproved_regions" {
  name        = "DenyUnapprovedRegions"
  description = "Denies access to all regions except us-east-1, eu-west-1 and af-south-1"
  content     = file("policies/scps/deny_unapproved_regions.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# SCP 2: Prevent leaving org
resource "aws_organizations_policy" "prevent_leaving_org" {
  name        = "PreventLeavingOrganization"
  description = "Prevents member accounts from leaving the organization"
  content     = file("policies/scps/prevent_leaving_org.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# scp 3: Prevent disabling CloudTrail
resource "aws_organizations_policy" "prevent_disable_cloudtrail" {
  name        = "PreventDisableCloudTrail"
  description = "Prevents member accounts from disabling CloudTrail"
  content     = file("policies/scps/prevent_disable_cloudtrail.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# SCP 4: Enforce encryption
resource "aws_organizations_policy" "enforce_encryption" {
  name        = "EnforceEncryption"
  description = "Enforces encryption for supported services"
  content     = file("policies/scps/enforce_encryption.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# SCP 5: Restrict root user
resource "aws_organizations_policy" "restrict_root_user" {
  name        = "RestrictRootUser"
  description = "Restricts the use of the root user"
  content     = file("policies/scps/restrict_root_user.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# SCP 6: Prevent deleting IAM Roles
resource "aws_organizations_policy" "prevent_delete_iam_roles" {
  name        = "PreventDeletingIAMRoles"
  description = "Prevents member accounts from deleting IAM Roles"
  content     = file("policies/scps/prevent_delete_iam_roles.json")
  type        = "SERVICE_CONTROL_POLICY"
}

# Attach to ROOT (applies to all accounts)
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

# Attach to SECURITY OU
resource "aws_organizations_policy_attachment" "restrict_root_user_security" {
  policy_id = aws_organizations_policy.restrict_root_user.id
  target_id = aws_organizations_organizational_unit.security.id
}

# Attach to WORKLOADS OU
resource "aws_organizations_policy_attachment" "enforce_encryption_workloads" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Member Accounts

# Security OU Accounts
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

# Workloads OU Accounts
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

# Attach region restriction SCP to Workloads OU
resource "aws_organizations_policy_attachment" "deny_regions_workloads" {
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id

  depends_on = [
    aws_organizations_organization.main,
    aws_organizations_organizational_unit.workloads,
    aws_organizations_policy.deny_unapproved_regions
  ]
}

data "aws_caller_identity" "current" {}
provider "aws" {
  alias   = "audit"
  region  = "us-east-1"
  profile = "management"

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.audit.id}:role/OrganizationAccountAccessRole"
  }
}

# Central Logging (Audit Account)
resource "aws_s3_bucket" "central_logs" {
  provider = aws.audit
  bucket   = "cental-logs-${aws_organizations_account.audit.id}"

  force_destroy = true
}

# Enabling versioning
resource "aws_s3_bucket_versioning" "central_logs" {
  provider = aws.audit
  bucket   = aws_s3_bucket.central_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Blocking public access
resource "aws_s3_bucket_public_access_block" "central_logs" {
  provider = aws.audit
  bucket   = aws_s3_bucket.central_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy allowing CloudTrail from all accounts
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
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.central_logs.arn]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
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
      identifiers = ["cloudtrail.amazonaws.com"]
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
      identifiers = ["config.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/*"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/GuardDuty/*"]
  }
}

# Organization cloudtrail (management account)
resource "aws_cloudtrail" "organization" {
  name                          = "organization-trail"
  s3_bucket_name                = aws_s3_bucket.central_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = true

  depends_on = [aws_s3_bucket_policy.central_logs]
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.organization.arn
}
