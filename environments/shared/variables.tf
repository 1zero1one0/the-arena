variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "centralus"
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "arena"
}
