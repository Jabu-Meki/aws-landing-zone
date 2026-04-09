locals {
  management_region = var.management_region
  phase_two_enabled = (
    var.existing_audit_account_id != "" &&
    var.existing_workload_account_id != ""
  )

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
}

provider "aws" {
  region = local.management_region
}

data "aws_caller_identity" "current" {}

# Organization Module
module "organization" {
  source = "./modules/organization"
  
  existing_organization_id  = var.existing_organization_id
  service_access_principals = local.organizations_service_access_principals
}

# Accounts Module
module "accounts" {
  source = "./modules/accounts"
  
  audit_account_email   = var.audit_account_email
  workload_account_email = var.workload_account_email
  security_ou_id        = module.organization.security_ou_id
  workloads_ou_id       = module.organization.workloads_ou_id
}

# SCP Module
module "scp" {
  source = "./modules/scp"
  
  root_id       = module.organization.root_id
  security_ou_id = module.organization.security_ou_id
  workloads_ou_id = module.organization.workloads_ou_id
}

provider "aws" {
  alias  = "audit"
  region = local.management_region

  assume_role {
    role_arn = "arn:aws:iam::${var.existing_audit_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "workload"
  region = local.management_region

  assume_role {
    role_arn = "arn:aws:iam::${var.existing_workload_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "logging" {
  count  = local.phase_two_enabled ? 1 : 0
  source = "./modules/logging"

  providers = {
    aws       = aws
    aws.audit = aws.audit
  }

  audit_account_id   = var.existing_audit_account_id
  organization_id    = module.organization.organization_id
  service_principals = local.service_principals
  current_account_id = data.aws_caller_identity.current.account_id
}

module "security" {
  count  = local.phase_two_enabled ? 1 : 0
  source = "./modules/security"

  providers = {
    aws.audit    = aws.audit
    aws.workload = aws.workload
  }

  log_bucket_name = module.logging[0].bucket_name
}
