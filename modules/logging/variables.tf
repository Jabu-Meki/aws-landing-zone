variable "audit_account_id" {
  description = "Audit account ID"
  type        = string
}

variable "organization_id" {
  description = "Organization ID"
  type        = string
}

variable "service_principals" {
  description = "Map of service principals"
  type        = map(string)
}

variable "current_account_id" {
  description = "Current AWS account ID"
  type        = string
}