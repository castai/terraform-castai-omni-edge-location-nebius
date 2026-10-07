variable "nebius_project_id" {
  type        = string
  description = "Nebius project ID that will own the edge location cloud resources."
}

variable "nebius_service_account_id" {
  type        = string
  sensitive   = true
  description = "Nebius service account ID used to authenticate the Nebius provider."
}

variable "nebius_public_key_id" {
  type        = string
  sensitive   = true
  description = "ID of the authorized public key uploaded to the Nebius service account."
}

variable "nebius_private_key_path" {
  type        = string
  description = "File path to the PEM-encoded private key for the Nebius service account."
}

variable "region" {
  type        = string
  description = "Region of the parent Nebius project (must match the project's actual region; validated during the run)."
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
    allows CAST AI to impersonate the Nebius service account created by this
    run.
  EOT
}

variable "editors_group_id" {
  type        = string
  default     = null
  description = "ID of an existing Nebius IAM group to add the CAST AI service account to. If not provided, a dedicated group is created."
}

variable "name" {
  type        = string
  description = "Base name for the edge location, used for the Nebius resource names (castai-omni-<name>...). Use the same name for the edge location itself so the two correlate."
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
