variable "castai_api_token" {
  type      = string
  sensitive = true
}

variable "castai_api_url" {
  type    = string
  default = "https://api.cast.ai"
}

variable "gke_project_id" {
  type = string
}

variable "gke_cluster_location" {
  type = string
}

variable "gke_cluster_name" {
  type = string
}

variable "nebius_project_id" {
  type        = string
  description = "Nebius project ID (parent_id) that will own the edge location resources. The project's region is derived automatically."
}

variable "nebius_service_account_id" {
  type        = string
  sensitive   = true
  description = "Nebius service account ID used to authenticate the Nebius provider."
}

variable "nebius_editors_group_id" {
  type        = string
  description = "Nebius editors group ID that holds permissions for SA"
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

variable "skip_helm" {
  description = "Skip installing any helm release; allows managing helm releases using GitOps"
  type        = bool
  default     = false
}
