# AWS Landing Zone

## Overview

This project provisions a foundational AWS landing zone using Terraform. It is designed to bootstrap an AWS Organization, create a basic organizational structure, apply service control policies (SCPs), create a small set of member accounts, and configure centralized logging and configuration visibility.

The current implementation uses:

- AWS Organizations for account and OU management
- Service Control Policies for baseline governance
- An audit account for centralized log storage
- AWS CloudTrail for organization-wide event logging
- AWS Config for configuration recording and organization aggregation

This repository is best understood as a practical landing-zone starter rather than a full enterprise landing-zone framework.

## What This Project Creates

At a high level, the Terraform configuration in `main.tf` creates the following:

- An AWS Organization with `ALL` features enabled
- Three Organizational Units:
  - `Security`
  - `Infrastructure`
  - `Workloads`
- Several Service Control Policies stored under `policies/scps`
- SCP attachments at the root and OU levels
- Four AWS member accounts:
  - `AuditAccount`
  - `SecurityToolsAccount`
  - `DevelopmentAccount`
  - `ProductionAccount`
- A centralized S3 log bucket in the audit account
- An organization CloudTrail trail
- AWS Config recorder, delivery channel, and configuration aggregator

## Architecture Summary

The intended architecture is:

1. The management account owns the AWS Organization and creates the OU structure.
2. Guardrails are enforced with SCPs at the root and OU levels.
3. The `AuditAccount` acts as the central destination for logs.
4. The management account assumes into the audit account using `OrganizationAccountAccessRole`.
5. CloudTrail delivers organization-level logs into the audit account S3 bucket.
6. AWS Config records configuration changes and aggregates organization-wide visibility.

This gives you a clean separation between governance, workloads, and centralized visibility.

## Organizational Structure

The current OU layout is:

- `Security`
  - `AuditAccount`
  - `SecurityToolsAccount`
- `Infrastructure`
  - No account is currently created here in the active configuration
- `Workloads`
  - `DevelopmentAccount`
  - `ProductionAccount`

## Service Control Policies Included

The following SCPs are currently managed by Terraform:

- `DenyUnapprovedRegions`
  - Restricts activity to approved AWS regions
- `PreventLeavingOrganization`
  - Prevents accounts from leaving the organization
- `PreventDisableCloudTrail`
  - Prevents CloudTrail from being disabled
- `EnforceEncryption`
  - Adds encryption-related restrictions for selected services
- `RestrictRootUser`
  - Restricts use of the root user
- `PreventDeletingIAMRoles`
  - Prevents deletion of IAM roles

These policies are defined as JSON files under `policies/scps`.

## Files and Project Layout

- `main.tf`
  - Main Terraform configuration for organization, accounts, SCPs, logging, and Config
- `outputs.tf`
  - Outputs for organization IDs, OU IDs, SCP IDs, account IDs, and logging/config resources
- `policies/scps`
  - SCP policy documents used by AWS Organizations
- `scripts/destroy.sh`
  - Helper destroy script if you choose to use it
- `destroy.sh`
  - Additional destroy helper in the repo root

## Prerequisites

Before using this project, make sure you have:

- Terraform `>= 1.5`
- AWS CLI installed and configured
- An AWS CLI profile named `management`
- Sufficient permissions in the management account to:
  - manage AWS Organizations
  - create and attach SCPs
  - create member accounts
  - create IAM roles and attach managed policies
  - create CloudTrail and AWS Config resources
- Permission to assume:
  - `arn:aws:iam::<audit-account-id>:role/OrganizationAccountAccessRole`

## AWS Credential Expectations

This project assumes the default management provider is configured like this:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "management"
}
```

It also assumes the management profile can assume into the audit account using:

```hcl
provider "aws" {
  alias   = "audit"
  region  = "us-east-1"
  profile = "management"

  assume_role {
    role_arn = "arn:aws:iam::<audit-account-id>:role/OrganizationAccountAccessRole"
  }
}
```

If your credentials are expired, invalid, or do not have `sts:AssumeRole` access into the audit account, `terraform plan` and `terraform apply` will fail.

## How to Use

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the Planned Changes

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

### 4. Inspect Outputs

```bash
terraform output
```

## Important Outputs

The project exports several useful values in `outputs.tf`, including:

- `organization_id`
- `organizational_units`
- `scp_ids`
- `member_accounts`
- `member_account_emails`
- `central_logs_bucket`
- `cloudtrail_arn`
- `config_aggregator_name`

## Operational Notes

### CloudTrail and S3 Bucket Policy

The organization CloudTrail trail depends on a correctly configured S3 bucket policy in the audit account. CloudTrail validates the bucket policy before trail creation, so missing permissions such as:

- `s3:GetBucketAcl`
- `s3:PutObject`

will cause trail creation to fail.

### AWS Config Delivery Requirements

AWS Config requires access to the delivery bucket. The bucket policy must permit:

- `s3:GetBucketAcl`
- `s3:ListBucket`
- `s3:PutObject`

for the `config.amazonaws.com` service principal.

### Cross-Account Access

The logging bucket is created in the audit account, not the management account. That means:

- the audit account must exist
- `OrganizationAccountAccessRole` must be present in the audit account
- the management account credentials must be allowed to assume that role

If any of these are not true, the audit logging portion of the Terraform configuration will fail.

### AWS Organizations Account Limits

AWS Organizations enforces account quotas. If you try to create more member accounts than your quota allows, Terraform will fail with an AWS Organizations constraint violation.

## Known Limitations

This project is functional, but it is still a simplified landing-zone implementation. Some limitations to keep in mind:

- Everything is currently defined in a single `main.tf` file rather than split into reusable modules
- Some values are hardcoded, including:
  - AWS region
  - account names
  - account emails
  - certain policy descriptions
- No remote backend is configured yet for Terraform state
- No Terraform variables are defined yet for environment-specific customization
- No CI/CD workflow is included for validation or deployment
- The configuration assumes a specific IAM access pattern for the audit account

## Recommended Improvements

If you continue developing this project, good next steps would be:

1. Split the configuration into modules:
   - organizations
   - accounts
   - SCPs
   - logging
   - config
2. Add `variables.tf` for:
   - region
   - profile
   - account emails
   - approved regions
3. Add a remote backend such as S3 with DynamoDB locking
4. Add validation checks and formatting in CI
5. Parameterize or template repeated policy logic
6. Introduce environment-aware naming conventions

## Disclaimers

### General Disclaimer

This project is provided as a learning and starter implementation. It is not a complete enterprise-grade landing zone and should not be treated as production-ready without further hardening, review, and testing.

### Security Disclaimer

Although this project applies governance controls such as SCPs, centralized logging, and AWS Config, it does not guarantee a secure AWS environment by itself. Security depends on additional controls, including:

- IAM least privilege
- network controls
- encryption strategy
- centralized monitoring and alerting
- incident response processes
- patching and vulnerability management

### Production Use Disclaimer

Do not apply this configuration directly to a production organization without:

- reviewing every SCP carefully
- validating account creation strategy
- confirming CloudTrail and Config requirements
- testing in a non-production AWS Organization first
- verifying cross-account trust and IAM permissions

### Cost Disclaimer

This project can create billable AWS resources, including:

- AWS member accounts
- S3 storage
- CloudTrail logging
- AWS Config recorders and aggregators

Running this Terraform code may incur AWS charges.

### State Management Disclaimer

If you are using local Terraform state, you are taking on operational risk. Local state is easier to lose, corrupt, or accidentally commit. For collaborative or long-lived use, move the state to a remote backend.

### Destructive Operations Disclaimer

Be careful with `terraform destroy` and any custom destroy scripts. Deleting organizations, accounts, audit buckets, or logging resources can be slow, restricted, or partially blocked by AWS service constraints and retention behavior.

## Conclusion

AWS Landing Zone gives you a practical starting point for organizing accounts, applying governance controls, and centralizing audit visibility in AWS. It is a strong foundation for learning and iteration, but it should be evolved further before being relied on as a full production landing-zone implementation.
