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


