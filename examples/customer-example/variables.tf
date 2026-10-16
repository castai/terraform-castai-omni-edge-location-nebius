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
  description = "Name for the edge location."
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the edge location."
}

# -----------------------------------------------------------------------------
# Handoff bundle from the cloud-resources run (its nebius_resources output).
#
# The bundle can be passed as-is: attributes beyond the ones declared below
# (federated_credentials_id, editors_group_id, editors_access_permit_id) are
# discarded by Terraform's object type conversion.
# -----------------------------------------------------------------------------

variable "nebius_handoff" {
  description = "Nebius handoff bundle produced by the cloud-resources run (its nebius_resources output): the Nebius cloud resources to attach the edge location to."
  type = object({
    parent_id          = string
    region             = string
    service_account_id = string
    network_id         = string
    subnet_id          = string
    subnet_cidr        = string
    security_group_id  = string
  })
}

# -----------------------------------------------------------------------------
# Edge configuration.
# -----------------------------------------------------------------------------

variable "ec_b200_nebius_me_west1" {
  description = <<-EOT
    Nebius edge configuration for the b200-nebius-me-west1 edge location.
    - image_id (string): Nebius image ID for edge instances.
    - reservation_ids (list(string)): Capacity block reservation IDs.
    - gpu_cluster_id (string): GPU cluster ID.
  EOT
  type = object({
    image_id        = string
    reservation_ids = list(string)
    gpu_cluster_id  = string
  })
}

# -----------------------------------------------------------------------------
# External LoadBalancer overrides for the control plane and the Liqo gateway.
# -----------------------------------------------------------------------------

variable "firewall_overrides" {
  description = <<-EOT
    External LoadBalancer overrides applied to both the edge location control plane and the Liqo gateway server.
    - azure_firewall_ip (string): Azure firewall IP that fronts the cluster; used as the external address for both the control plane and the Liqo gateway.
    - kmc_internal_lb_ip (string): in-cluster internal LoadBalancer IP of the control plane (KMC) service.
    - liqo_internal_lb_ip (string): in-cluster internal LoadBalancer IP of the Liqo gateway service.
  EOT
  type = object({
    azure_firewall_ip   = string
    kmc_internal_lb_ip  = string
    liqo_internal_lb_ip = string
  })
}
