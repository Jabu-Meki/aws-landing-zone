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
