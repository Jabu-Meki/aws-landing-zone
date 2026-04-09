data "aws_organizations_organization" "current" {}

locals {
  use_existing_organization = var.existing_organization_id != ""
  root_id = local.use_existing_organization ? data.aws_organizations_organization.current.roots[0].id : aws_organizations_organization.main[0].roots[0].id
}

resource "aws_organizations_organization" "main" {
  count = local.use_existing_organization ? 0 : 1

  feature_set = "ALL"
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]

  aws_service_access_principals = var.service_access_principals

  lifecycle {
    precondition {
      condition     = !local.use_existing_organization
      error_message = "Set existing_organization_id only when reusing an existing organization."
    }
  }
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}
