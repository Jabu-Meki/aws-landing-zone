output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "organizational_units" {
  description = "Organizational unit IDs"
  value = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workloads      = aws_organizations_organizational_unit.workloads.id
  }
}

output "scp_ids" {
  description = "Service control policy IDs"
  value = {
    deny_unapproved_regions    = aws_organizations_policy.deny_unapproved_regions.id
    prevent_leaving_org        = aws_organizations_policy.prevent_leaving_org.id
    prevent_disable_cloudtrail = aws_organizations_policy.prevent_disable_cloudtrail.id
    enforce_encryption         = aws_organizations_policy.enforce_encryption.id
    restrict_root_user         = aws_organizations_policy.restrict_root_user.id
    prevent_delete_iam_roles   = aws_organizations_policy.prevent_delete_iam_roles.id
  }
}

output "member_accounts" {
  description = "Member account IDs"
  value = {
    audit          = aws_organizations_account.audit.id
    security_tools = aws_organizations_account.security_tools.id
    dev            = aws_organizations_account.dev.id
    prod           = aws_organizations_account.prod.id
  }
}

output "member_account_emails" {
  description = "Member account emails"
  value = {
    audit          = aws_organizations_account.audit.email
    security_tools = aws_organizations_account.security_tools.email
    dev            = aws_organizations_account.dev.email
    prod           = aws_organizations_account.prod.email
  }
  sensitive = true
}

output "central_logs_bucket" {
  description = "Central S3 bucket used for organization logs"
  value       = aws_s3_bucket.central_logs.id
}

output "cloudtrail_arn" {
  description = "Organization CloudTrail ARN"
  value       = aws_cloudtrail.organization.arn
}

output "config_aggregator_name" {
  description = "AWS Config organization aggregator name"
  value       = aws_config_configuration_aggregator.organization.name
}
