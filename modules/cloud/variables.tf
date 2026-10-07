variable "name" {
  type        = string
  description = "Base name for the edge location, used for the Nebius resource names (castai-omni-<name>...). Use the same name for the edge location itself (see the edgelocation submodule / root module) so full-mode naming stays consistent."

  validation {
    # Nebius resource names are limited to 63 chars. The name is prefixed with
    # "castai-omni-" (12 chars) and the longest suffix is "-ingress-self"
    # (13 chars), so the sanitized name must be at most 38 chars. replace()
    # maps each character 1:1, so the sanitized length equals the raw length.
    condition = length(lower(replace(var.name, "/[^a-zA-Z0-9-]/", "-"))) <= 63 - 12 - 13

    error_message = "name must be at most 38 characters after sanitization so that prefixed and suffixed resource names fit within Nebius' 63-character limit."
  }
}

variable "parent_id" {
  description = <<-EOT
    Nebius project ID that will own the edge location resources (VPC network,
    subnet, security group, service account). Must match the parent project
    configured in the Nebius provider.

    Nebius projects are created per region, so var.region must match the
    project's region; it is validated against the project during this run.
  EOT
  type        = string

  validation {
    condition     = var.parent_id != null && var.parent_id != ""
    error_message = "parent_id (Nebius project ID) must be set."
  }
}

variable "region" {
  type        = string
  description = "Region of the parent Nebius project (must match the project's actual region; validated during this run)."
}

variable "cluster_id" {
  type        = string
  description = "CAST AI cluster ID of the Omni cluster the edge location will be attached to. Used for resource labels (cast-omni:cluster-id)."
}

variable "castai_oidc_subject_id" {
  description = <<-EOT
    CAST AI GCP service account unique ID of the Omni cluster, used as the
    federated subject of the Nebius WIF credential. It is read from the
    castai_omni_cluster data source
    (castai_oidc_config.gcp_service_account_unique_id) by the owner of the
    edge location (or of the cluster) and provided by them when the cloud
    resources and the edge location are owned by different parties.
  EOT
  type        = string

  validation {
    condition     = var.castai_oidc_subject_id != null && var.castai_oidc_subject_id != ""
    error_message = "castai_oidc_subject_id must be set (read it from the castai_omni_cluster data source: castai_oidc_config.gcp_service_account_unique_id)."
  }
}

variable "editors_group_id" {
  description = <<-EOT
    ID of the Nebius IAM group (e.g. the default `editors` group in the project)
    that the CAST AI service account will be added to so it can manage compute
    and network resources. If not provided, a dedicated IAM group is created
    automatically and granted the `editor` role on the project, so no
    out-of-band permission setup is required.
  EOT
  type        = string
  default     = null
}

variable "network_cidr" {
  description = "CIDR block for the Nebius network address pool. Defines the network's private IPv4 address space."
  type        = string
  default     = "10.0.0.0/13"
}

variable "subnet_cidr" {
  description = "CIDR block for the Nebius subnet. Must be within the network CIDR (var.network_cidr)."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    # Check both mask specificity and address containment: the subnet mask
    # must be >= the network mask (smaller block), and masking the subnet's
    # network address with the network's prefix must yield the network's own
    # address.
    condition     = tonumber(split("/", var.subnet_cidr)[1]) >= tonumber(split("/", var.network_cidr)[1]) && cidrhost(format("%s/%s", cidrhost(var.subnet_cidr, 0), split("/", var.network_cidr)[1]), 0) == cidrhost(var.network_cidr, 0)
    error_message = "subnet_cidr must be within the network_cidr address range."
  }
}

variable "tags" {
  description = "Labels to apply to Nebius resources (Nebius calls these `labels`)"
  type        = map(string)
  default     = {}
}
