variable "audit_account_email" {
  description = "Email for audit account"
  type        = string
  default     = "jabulanimeki+audit@outlook.com"
}

variable "workload_account_email" {
  description = "Email for workload account"
  type        = string
  default     = "jabulanimeki+workload@outlook.com"
}

variable "management_region" {
  description = "AWS region for management resources"
  type        = string
  default     = "us-east-1"
}

variable "existing_organization_id" {
  description = "Existing AWS Organization ID to use instead of creating a new organization. Leave empty to create a new organization."
  type        = string
  default     = ""
}

variable "existing_audit_account_id" {
  description = "Existing audit account ID to use for cross-account resources. Leave empty during the initial organization bootstrap."
  type        = string
  default     = ""
}

variable "existing_workload_account_id" {
  description = "Existing workload account ID to use for cross-account resources. Leave empty during the initial organization bootstrap."
  type        = string
  default     = ""
}
