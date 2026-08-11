variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "upwind_region" {
  description = "Upwind region to connect to."
  type        = string
  default     = "us"
}

variable "upwind_organization_id" {
  description = "Upwind organization ID."
  type        = string
}

variable "upwind_integration_client_id" {
  description = "Upwind client ID for the integration."
  type        = string
}

variable "upwind_integration_client_secret" {
  description = "Upwind client secret."
  type        = string
  sensitive   = true
}
