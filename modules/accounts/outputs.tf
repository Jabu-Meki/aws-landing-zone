output "audit_account_id" {
  value = aws_organizations_account.audit.id
}

output "workload_account_id" {
  value = aws_organizations_account.workload.id
}