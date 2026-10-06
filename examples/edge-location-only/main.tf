# =============================================================================
# Edge-location-only mode: provision only the CAST AI edge location.
#
# The Nebius cloud resources were provisioned separately (see the
# cloud-only example) and are referenced via the handoff bundle; no Nebius
# credentials are required.
#
# The castai_omni_cluster data source below is only needed to obtain the
# OIDC subject that the edge location owner provides to the cloud resources
# owner BEFORE the cloud resources are provisioned - it is not needed for
# the edge location itself.
# =============================================================================

data "castai_omni_cluster" "this" {
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
}

output "castai_oidc_subject_id_for_cloud_resources_owner" {
  description = "Hand this single string to the owner of the cloud resources before the cloud resources are provisioned: the WIF federated subject binding CAST AI to the Nebius service account"
  value       = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_unique_id
}

module "castai_nebius_edge_location" {
  source = "../.."

  # Reference the separately-provisioned cloud resources instead of
  # creating them.
  provision_cloud = false

  organization_id = var.organization_id
  cluster_id      = var.cluster_id

  # Handoff bundle from the run that provisioned the cloud resources (its
  # nebius_resources output).
  parent_id = var.nebius_parent_id
  region    = var.region

  existing_nebius_resources = {
    service_account_id = var.nebius_service_account_id
    network_id         = var.nebius_network_id
    subnet_id          = var.nebius_subnet_id
    subnet_cidr        = var.nebius_subnet_cidr
    security_group_id  = var.nebius_security_group_id
  }

  name        = var.name
  description = var.description

  # Optional: edge configurations for edge instances.
  # edge_configurations = {
  #   default = {
  #     name     = "default"
  #     image_id = "..."
  #   }
  # }
  # default_edge_configuration_name = "default"

  # Optional: wait for the location to become ready before finishing.
  # Requires api_url and api_token.
  # wait_for_location_ready = true
}
