output "organization_id" {
  value = module.organization.organization_id
}

output "audit_account_id" {
  value = module.accounts.audit_account_id
}

output "workload_account_id" {
  value = module.accounts.workload_account_id
}

output "central_logs_bucket" {
  value = local.phase_two_enabled ? module.logging[0].bucket_name : null
}
