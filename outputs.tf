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
    deny_unapproved_regions = aws_organizations_policy.deny_unapproved_regions.id
  }
}


