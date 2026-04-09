resource "aws_organizations_policy" "deny_unapproved_regions" {
  name        = "DenyUnapprovedRegions"
  description = "Denies access to all regions except us-east-1, eu-west-1 and af-south-1"
  content     = file("${path.root}/policies/scps/deny_unapproved_regions.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_leaving_org" {
  name        = "PreventLeavingOrganization"
  description = "Prevents member accounts from leaving the organization"
  content     = file("${path.root}/policies/scps/prevent_leaving_org.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_disable_cloudtrail" {
  name        = "PreventDisableCloudTrail"
  description = "Prevents member accounts from disabling CloudTrail"
  content     = file("${path.root}/policies/scps/prevent_disable_cloudtrail.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_disable_config" {
  name        = "PreventDisableConfig"
  description = "Prevents member accounts from disabling AWS Config"
  content     = file("${path.root}/policies/scps/prevent_disable_config.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_disable_guardduty" {
  name        = "PreventDisableGuardDuty"
  description = "Prevents member accounts from disabling GuardDuty"
  content     = file("${path.root}/policies/scps/prevent_disable_guardduty.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "enforce_encryption" {
  name        = "EnforceEncryption"
  description = "Enforces encryption for supported services"
  content     = file("${path.root}/policies/scps/enforce_encryption.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "restrict_root_user" {
  name        = "RestrictRootUser"
  description = "Restricts the use of the root user"
  content     = file("${path.root}/policies/scps/restrict_root_user.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "prevent_delete_iam_roles" {
  name        = "PreventDeletingIAMRoles"
  description = "Prevents member accounts from deleting IAM roles"
  content     = file("${path.root}/policies/scps/prevent_delete_iam_roles.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "restrict_ec2_instance_types" {
  name        = "RestrictEC2InstanceTypes"
  description = "Restricts EC2 launches to approved instance types"
  content     = file("${path.root}/policies/scps/restrict_ec2_instance_types.json")
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy_attachment" "prevent_leaving_org_root" {
  policy_id = aws_organizations_policy.prevent_leaving_org.id
  target_id = var.root_id
}

resource "aws_organizations_policy_attachment" "prevent_disable_cloudtrail_security" {
  policy_id = aws_organizations_policy.prevent_disable_cloudtrail.id
  target_id = var.security_ou_id
}

resource "aws_organizations_policy_attachment" "prevent_disable_cloudtrail_workloads" {
  policy_id = aws_organizations_policy.prevent_disable_cloudtrail.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "prevent_disable_config_root" {
  policy_id = aws_organizations_policy.prevent_disable_config.id
  target_id = var.root_id
}

resource "aws_organizations_policy_attachment" "prevent_disable_guardduty_root" {
  policy_id = aws_organizations_policy.prevent_disable_guardduty.id
  target_id = var.root_id
}

resource "aws_organizations_policy_attachment" "prevent_delete_iam_roles_root" {
  policy_id = aws_organizations_policy.prevent_delete_iam_roles.id
  target_id = var.root_id
}

resource "aws_organizations_policy_attachment" "restrict_root_user_security" {
  policy_id = aws_organizations_policy.restrict_root_user.id
  target_id = var.security_ou_id
}

resource "aws_organizations_policy_attachment" "deny_regions_workloads" {
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "enforce_encryption_workloads" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "restrict_ec2_instance_types_workloads" {
  policy_id = aws_organizations_policy.restrict_ec2_instance_types.id
  target_id = var.workloads_ou_id
}
