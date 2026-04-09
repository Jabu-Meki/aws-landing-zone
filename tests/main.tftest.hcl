run "validate_organization" {
  command = plan

  assert {
    condition     = output.organization_id != ""
    error_message = "Organization must be created"
  }
}

run "validate_accounts" {
  command = plan

  assert {
    condition     = output.audit_account_id != ""
    error_message = "Audit account must be created"
  }

  assert {
    condition     = output.workload_account_id != ""
    error_message = "Workload account must be created"
  }
}

run "validate_logging" {
  command = plan

  assert {
    condition     = var.existing_audit_account_id != "" && var.existing_workload_account_id != "" ? output.central_logs_bucket != null : output.central_logs_bucket == null
    error_message = "Logging output should exist only when phase two account IDs are configured"
  }
}
