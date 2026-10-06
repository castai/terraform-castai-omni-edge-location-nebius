variable "castai_api_token" {
  type        = string
  sensitive   = true
  description = "CAST AI API token. Required even in cloud-only mode: Terraform configures the castai provider for all module resources, even with count = 0."
}

variable "nebius_project_id" {
  type        = string
  description = "Nebius project ID that will own the edge location cloud resources."
}

variable "region" {
  type        = string
  description = "Region of the parent Nebius project (must match the project's actual region; validated during the run)."
}

variable "organization_id" {
  type        = string
  description = "CAST AI organization ID of the cluster. Used for bookkeeping only in this mode (no CAST AI resources are created)."
}

variable "cluster_id" {
  type        = string
  description = "CAST AI cluster ID of the Omni cluster. Used for resource labels (cast-omni:cluster-id)."
}

variable "castai_oidc_subject_id" {
  type        = string
  description = <<-EOT
    CAST AI GCP service account unique ID of the Omni cluster, provided by
    the owner of the edge location. It is the WIF federated subject that
    allows CAST AI to impersonate the Nebius service account created by
    this module.
  EOT
}

variable "editors_group_id" {
  type        = string
  default     = null
  description = "ID of an existing Nebius IAM group to add the CAST AI service account to. If not provided, a dedicated group is created."
}

variable "name" {
  type        = string
  default     = null
  description = "Base name for the edge location cloud resources. If not provided, will be auto-generated."
}

variable "network_cidr" {
  type        = string
  default     = "10.0.0.0/13"
  description = "CIDR block for the Nebius network address pool."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR block for the Nebius subnet. Must be within the network CIDR."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to Nebius resources."
}
