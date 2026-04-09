resource "aws_organizations_account" "audit" {
  name      = "AuditAccount"
  email     = var.audit_account_email
  parent_id = var.security_ou_id

  tags = {
    Purpose = "Central logging and audit storage"
  }
}

resource "aws_organizations_account" "workload" {
  name      = "WorkloadAccount"
  email     = var.workload_account_email
  parent_id = var.workloads_ou_id

  tags = {
    Purpose     = "Application workloads"
    Environment = "prod"
  }
}