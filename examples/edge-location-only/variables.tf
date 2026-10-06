variable "castai_api_token" {
  type        = string
  sensitive   = true
  description = "CAST AI API token."
}

variable "castai_api_url" {
  type        = string
  default     = "https://api.cast.ai"
  description = "CAST AI API URL."
}

variable "organization_id" {
  type        = string
  description = "CAST AI organization ID."
}

variable "cluster_id" {
  type        = string
  description = "CAST AI cluster ID of the Omni cluster (onboarded to CAST AI with OMNI enabled)."
}

variable "name" {
  type        = string
  description = "Name for the edge location. Typically the name from the handoff bundle (the cloud run's nebius_resources output includes it) so the edge location correlates with its cloud resources."
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the edge location."
}

# -----------------------------------------------------------------------------
# Handoff bundle from the cloud-resources run (its nebius_resources output).
# -----------------------------------------------------------------------------

variable "nebius_parent_id" {
  type        = string
  description = "Nebius project ID that owns the edge cloud resources (from the handoff bundle)."
}

variable "region" {
  type        = string
  description = "Nebius region of the cloud resources (from the handoff bundle)."
}

variable "nebius_service_account_id" {
  type        = string
  description = "Nebius service account impersonated by CAST AI (from the handoff bundle)."
}

variable "nebius_network_id" {
  type        = string
  description = "VPC network for edge instances (from the handoff bundle)."
}

variable "nebius_subnet_id" {
  type        = string
  description = "Subnet for edge instances (from the handoff bundle)."
}

variable "nebius_subnet_cidr" {
  type        = string
  description = "IPv4 CIDR of the subnet (from the handoff bundle)."
}

variable "nebius_security_group_id" {
  type        = string
  description = "Security group for edge instances (from the handoff bundle)."
}
