variable "service_access_principals" {
  description = "List of AWS service principals for organization access"
  type        = list(string)
}

variable "existing_organization_id" {
  description = "Existing AWS Organization ID to use instead of creating a new organization."
  type        = string
  default     = ""
}
