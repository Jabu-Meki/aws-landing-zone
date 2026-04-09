# AWS Landing Zone

## Overview

This repository provisions a Terraform-based AWS landing zone for an AWS Organization. It is designed to establish a clean governance baseline, create core organizational structure, provision member accounts, and prepare centralized security and logging services.

The project is intentionally organized as a reusable module-based implementation rather than a single flat Terraform file. It is aimed at demonstrating practical cloud platform engineering patterns:

- organization-aware infrastructure design
- governance with Service Control Policies
- account provisioning through AWS Organizations
- cross-account access with assumed roles
- centralized logging and security service onboarding

## What This Project Delivers

The current implementation is built around five functional areas:

- `organization`
  Creates or reuses an AWS Organization and provisions the core OU structure.
- `accounts`
  Creates the member accounts used by the landing zone.
- `scp`
  Creates and attaches governance guardrails through Service Control Policies.
- `logging`
  Provisions centralized S3-based audit logging and an organization CloudTrail trail.
- `security`
  Provisions GuardDuty, AWS Config, and baseline AWS Config rules across member accounts.

## Current Architecture

The root configuration in [main.tf](/home/jabu/Documents/AWS-Projects/aws-landing-zone/main.tf) coordinates a two-stage operating model:

1. Organization and governance bootstrap
   - reuse or create the organization
   - create organizational units
   - create member accounts
   - apply SCP guardrails
2. Cross-account security and logging enablement
   - assume into the member accounts
   - create centralized logging resources
   - enable CloudTrail
   - enable GuardDuty
   - enable AWS Config and baseline Config rules

This structure reflects a real-world constraint of AWS Organizations: account creation can complete before every target AWS service is fully usable in the new accounts.

## Organizational Structure

The project provisions or manages the following OU layout:

- `Security`
- `Infrastructure`
- `Workloads`

The current account model is intentionally simple:

- `AuditAccount`
- `WorkloadAccount`

This keeps the landing-zone footprint small while still demonstrating multi-account governance and cross-account operations.

## Governance Controls

The repository includes SCP documents under [policies/scps](/home/jabu/Documents/AWS-Projects/aws-landing-zone/policies/scps) and applies governance controls through the `scp` module.

Current policies include controls for:

- region restrictions
- CloudTrail protection
- AWS Config protection
- GuardDuty protection
- preventing organization departure
- restricting root usage
- preventing IAM role deletion
- EC2 instance type restrictions
- selected encryption-related controls

Because AWS Organizations enforces a maximum number of SCP attachments per target, the policy layout is intentionally distributed across the organization root and specific OUs rather than attaching every policy to the root.

## Security and Logging Design

The intended service flow is:

- the management account owns the AWS Organization and orchestrates provisioning
- the audit account serves as the central destination for log storage
- the management account creates the organization CloudTrail trail
- member accounts are accessed through `OrganizationAccountAccessRole`
- GuardDuty is enabled within member accounts
- AWS Config is enabled within member accounts and aggregated centrally

The module code for logging and security is present and wired into the root configuration. The remaining operational dependency is AWS service readiness in the newly created child accounts.

## Repository Layout

- [main.tf](aws-landing-zone/main.tf)
  Root module wiring, providers, and module orchestration.
- [variables.tf](aws-landing-zone/variables.tf)
  Root input variables for organization reuse, region, accounts, and phase-two account IDs.
- [outputs.tf](aws-landing-zone/outputs.tf)
  Root outputs for organization and account identifiers plus centralized logging output when phase two is enabled.
- [versions.tf](aws-landing-zone/versions.tf)
  Terraform and provider version declarations.
- [tests/main.tftest.hcl](aws-landing-zone/tests/main.tftest.hcl)
  Terraform test assertions for the root module.
- [modules/organization](aws-landing-zone/modules/organization)
  Organization and OU management.
- [modules/accounts](aws-landing-zone/modules/accounts)
  Member account creation.
- [modules/scp](aws-landing-zone/modules/scp)
  SCP creation and attachment logic.
- [modules/logging](aws-landing-zone/modules/logging)
  Central S3 audit bucket and organization CloudTrail resources.
- [modules/security](aws-landing-zone/modules/security)
  GuardDuty, AWS Config, and baseline Config rules.
- [ERROR_NOTES.md](aws-landing-zone/ERROR_NOTES.md)
  Detailed troubleshooting history, resolved issues, and current blockers.

## Credentials and Access Model

The root AWS provider now uses the default AWS credential chain rather than a hardcoded CLI profile.

That means Terraform can authenticate through:

- the default AWS CLI profile
- environment variables
- federated or temporary credentials
- an attached IAM role in a supported runtime

Cross-account operations use aliased providers that assume into the member accounts through `OrganizationAccountAccessRole`.

## Inputs

The root module accepts these primary inputs:

- `audit_account_email`
- `workload_account_email`
- `management_region`
- `existing_organization_id`
- `existing_audit_account_id`
- `existing_workload_account_id`

The `existing_*_account_id` variables are used to enable the phase-two cross-account modules once the member accounts exist and are reachable.

## Outputs

The root module currently exports:

- `organization_id`
- `audit_account_id`
- `workload_account_id`
- `central_logs_bucket`

`central_logs_bucket` is populated only when the phase-two logging module is enabled.

## Verified Working Areas

The following parts of the project have been verified successfully in the current repository state:

- reusing an existing AWS Organization
- creating and managing organizational units
- creating member accounts through AWS Organizations
- applying SCPs to the organization root and OUs
- assuming into the created member accounts through `OrganizationAccountAccessRole`
- successful `terraform init`
- successful `terraform validate`
- successful `terraform plan`

These are meaningful landing-zone capabilities and represent the working foundation of the project.

## Full Blocker

The current end-to-end blocker is AWS service activation inside freshly created child accounts.

Although the newly created accounts are active in AWS Organizations and cross-account role assumption works, AWS has not consistently allowed immediate use of some services in those member accounts. In testing, this affected:

- S3 in the audit account
- GuardDuty in child accounts
- AWS Config in child accounts

As a result, the Terraform code for centralized logging and security services can plan correctly but may fail to apply until AWS fully activates those services in the new accounts.

This is the primary outstanding limitation for full automation at the moment.

## How to Use

### 1. Initialize

```bash
terraform init
```

### 2. Validate

```bash
terraform validate
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

### 5. Inspect outputs

```bash
terraform output
```

## Recommended Operating Pattern

For real-world use, the cleanest approach is:

1. Bootstrap the organization, OUs, accounts, and SCPs.
2. Confirm the target member accounts are fully accessible and service-ready.
3. Enable logging and security resources through the same repository using the existing account IDs.

This keeps the implementation honest to AWS Organizations behavior while still preserving a single cohesive codebase.

## Professional Notes

This project should be understood as a serious infrastructure engineering exercise rather than a toy example. It demonstrates:

- AWS Organizations design
- Terraform module composition
- governance enforcement with SCPs
- cross-account provider design
- phased landing-zone rollout strategy
- honest handling of real AWS operational constraints

The codebase is deliberately practical: it does not hide the fact that some cloud automation problems are shaped as much by provider readiness and account lifecycle behavior as by Terraform itself.

## Limitations

This repository is not yet a fully production-ready enterprise landing zone. It currently does not include:

- a remote Terraform backend
- CI/CD validation pipelines
- account vending workflows beyond the two current member accounts
- mature operational runbooks for partial-failure recovery
- service readiness orchestration for newly created child accounts

These are natural next steps for further hardening.

## Documentation

Project troubleshooting and the full record of issues encountered during implementation are intentionally kept out of the README and tracked in [ERROR_NOTES.md](aws-landing-zone/ERROR_NOTES.md).

## Summary

This repository provides a strong Terraform foundation for an AWS landing zone:

- organization structure works
- account provisioning works
- governance guardrails work
- cross-account access works
- the logging and security implementation is present and structured correctly

The remaining gap is not missing intent or missing code. It is AWS child-account service readiness for full phase-two enablement.
