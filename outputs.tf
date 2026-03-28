output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "organizational_units" {
  description = "All OUs with thier IDs"
  value = {
    security       = aws_organizations_organizational_unit.security.id,
    infrastructure = aws_organizations_organizational_unit.infrastructure.id,
    workloads      = aws_organizations_organizational_unit.workloads.id
  }
}

output "scp_ids" {
  description = "All SCPs with their IDs"
  value = {
    deny_unapproved_regions    = aws_organizations_policy.deny_unapproved_regions.id
    prevent_leaving_org        = aws_organizations_policy.prevent_leaving_org.id
    prevent_disable_cloudtrail = aws_organizations_policy.prevent_disable_cloudtrail.id
    enforce_encryption         = aws_organizations_policy.enforce_encryption.id
    restrict_root_user         = aws_organizations_policy.restrict_root_user.id
    prevent_delete_iam_roles   = aws_organizations_policy.prevent_delete_iam_roles.id
  }
}

output "scp_attachments" {
  description = "Where each SCP is attached"
  value = {
    prevent_leaving_org        = "Root (all accounts)"
    prevent_disable_cloudtrail = "Root (all accounts)"
    prevent_delete_iam_roles   = "Root (all accounts)"
    deny_unapproved_regions    = "Workloads OU"
    enforce_encryption         = "Workloads OU"
    restrict_root_user         = "Security OU"
  }
}


