# Error Notes

## Purpose

This document captures the implementation issues encountered while building the landing zone, the fixes that were applied, and the current blocker that remains outside normal Terraform syntax and wiring concerns.

## Current Project State

Verified working:

- `terraform init`
- `terraform validate`
- `terraform plan`
- reusing an existing AWS Organization
- creating and managing OUs
- creating AWS member accounts
- creating and attaching SCPs
- cross-account assume-role access into the created member accounts

Partially blocked:

- full phase-two creation of S3 logging, CloudTrail, GuardDuty, and AWS Config

## What Was Fixed

### 1. Duplicate Terraform provider declarations

Problem:

- the root module previously defined `required_providers` in more than one place

Fix:

- consolidated provider requirements into `versions.tf`

Result:

- `terraform validate` no longer failed on duplicate provider configuration

### 2. Drift between flattened and modular root structures

Problem:

- parts of the repository referenced a flattened root module
- other parts referenced a module-based root

Fix:

- standardized the root on the module-based architecture
- aligned outputs and tests with that structure

Result:

- the repository now plans and validates against a single coherent architecture

### 3. Broken outputs and tests

Problem:

- `outputs.tf` and `tests/main.tftest.hcl` referenced resources or modules that no longer matched the active root shape

Fix:

- rewired outputs to the active module outputs
- updated tests to assert against the correct root outputs

Result:

- output references are valid
- Terraform test assertions align with the root module

### 4. Hardcoded management profile

Problem:

- the root providers were pinned to `profile = "management"`

Fix:

- removed the hardcoded profile usage
- switched to the default AWS credential chain

Result:

- the repository now works with standard AWS authentication patterns

### 5. Undefined provider warnings in child modules

Problem:

- the root module passed provider aliases into child modules that did not explicitly declare them

Fix:

- added `required_providers` declarations to child modules
- added `configuration_aliases` where needed

Result:

- provider mappings are explicit and Terraform configuration is cleaner

### 6. Existing organization handling

Problem:

- the original module path assumed it should always create a brand-new AWS Organization
- applying into an existing management account failed with `AlreadyInOrganizationException`

Fix:

- updated the organization module to support reuse of an existing organization through `existing_organization_id`

Result:

- the repository now works against an existing AWS Organization

### 7. SCP module implementation

Problem:

- `module "scp"` existed in the root module
- `modules/scp/main.tf` was empty

Fix:

- implemented policy creation and policy attachment logic

Result:

- SCPs are now actively managed by Terraform

### 8. SCP enablement on the organization root

Problem:

- policy attachments failed with `PolicyTypeNotEnabledException`

Fix:

- enabled `SERVICE_CONTROL_POLICY` on the organization root

Result:

- SCP attachments could proceed

### 9. Root SCP attachment limit

Problem:

- AWS Organizations refused additional SCP attachments at the root with `ConstraintViolationException`
- the root had reached the maximum number of attached SCPs

Fix:

- moved the CloudTrail protection SCP off the root
- attached it to the `Security` and `Workloads` OUs instead

Result:

- Terraform apply completed successfully for the remaining SCP attachments

### 10. Reintroducing phase-two services safely

Problem:

- the original cross-account providers depended on account IDs created in the same run
- that caused provider-configuration instability

Fix:

- reintroduced phase-two logging and security modules using explicit existing account IDs
- wired aliased providers against stable account IDs instead of unknown values

Result:

- Terraform can plan the logging and security phase correctly

## What Currently Works in AWS

Confirmed through Terraform and AWS API behavior:

- existing organization reuse
- OU creation
- account creation
- SCP creation
- SCP attachment
- role assumption into the audit account
- role assumption into the workload account

This means the governance and account bootstrap path is working as designed.

## Current Blocker

### AWS child-account service readiness

The remaining blocker is not Terraform syntax or wiring.

The newly created child accounts are:

- visible in AWS Organizations
- marked `ACTIVE`
- accessible through `OrganizationAccountAccessRole`

However, AWS has not consistently allowed immediate usage of certain services inside those child accounts.

Observed failures included:

- S3 in the audit account returning `NotSignedUp`
- GuardDuty in child accounts returning `SubscriptionRequiredException`
- AWS Config in child accounts returning `SubscriptionRequiredException`
- AWS console access for the new accounts looping through additional verification checks

## Why This Matters

The logging and security modules are now present and correctly connected:

- the audit S3 bucket is intended to live in the audit account
- the organization CloudTrail trail depends on that bucket
- GuardDuty detectors are created directly in child accounts
- AWS Config recorders and rules are created directly in child accounts

Because AWS is not yet allowing those service APIs in the new accounts, full phase-two apply is blocked despite the Terraform design being structurally correct.

## Honest Engineering Conclusion

At this point, the repo should not be described as “broken.”

A more accurate statement is:

- the landing-zone bootstrap path works
- the governance path works
- the cross-account security and logging implementation is present
- AWS child-account service activation is the remaining blocker to full end-to-end success

## Recommended Next Step

If the child accounts continue to reject S3, GuardDuty, and AWS Config after a reasonable wait period:

1. Open an AWS Support case from the management account.
2. Provide:
   - organization ID
   - management account ID
   - member account IDs
   - the console verification loop behavior
   - the `NotSignedUp` and `SubscriptionRequiredException` responses
3. Ask AWS to verify account activation and service readiness for the newly created organization member accounts.

## Repository Implication

The correct project posture is:

- keep the repository
- document the bootstrap and governance success clearly
- document the AWS service-readiness blocker honestly
- continue from there once AWS finishes activating the child accounts
