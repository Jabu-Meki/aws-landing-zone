output "organization_id" {
  value = var.existing_organization_id != "" ? data.aws_organizations_organization.current.id : aws_organizations_organization.main[0].id
}

output "root_id" {
  value = local.root_id
}

output "security_ou_id" {
  value = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  value = aws_organizations_organizational_unit.infrastructure.id
}

output "workloads_ou_id" {
  value = aws_organizations_organizational_unit.workloads.id
}
