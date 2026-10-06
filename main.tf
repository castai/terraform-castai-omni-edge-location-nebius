# Nebius Edge Location for CAST AI
#
# Full mode: this root module provisions both the Nebius cloud resources
# (modules/cloud) and the CAST AI edge location (modules/edgelocation) in a
# single run, requiring both Nebius and CAST AI credentials.
#
# When the cloud resources and the edge location are owned by different
# parties, each party calls its submodule directly instead:
#   - the cloud resources owner calls modules/cloud (Nebius credentials only)
#   - the edge location owner calls modules/edgelocation (CAST AI credentials
#     only), consuming modules/cloud's nebius_resources output
# See the README for the handoff sequence.

# Generate random suffix for the edge location name
resource "random_id" "suffix" {
  byte_length = 4
}

# Fetch CAST AI Omni cluster OIDC config. Used to model the impersonation
# contract between CAST AI and the Nebius service account: the WIF federated
# subject is the CAST AI GCP service account unique ID of the Omni cluster.
data "castai_omni_cluster" "this" {
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
}

locals {
  # Generate name if not provided (with random suffix). Computed once here and
  # passed to both submodules so the cloud resource names and the edge location
  # name stay consistent.
  generated_name = var.name != null ? var.name : "nebius-${var.region}-${random_id.suffix.hex}"
}

# Validation: ensure required variables are consistent.
resource "null_resource" "validate" {
  lifecycle {
    precondition {
      condition     = var.parent_id != null && var.parent_id != ""
      error_message = "parent_id (Nebius project ID) must be set."
    }
  }
}

# =============================================================================
# Nebius cloud resources: service account, WIF federated credentials, editors
# group, VPC network/subnet, security group.
# =============================================================================

module "cloud" {
  source = "./modules/cloud"

  name       = local.generated_name
  parent_id  = var.parent_id
  region     = var.region
  cluster_id = var.cluster_id

  # WIF federated subject: the Omni cluster's CAST AI GCP identity.
  castai_oidc_subject_id = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_unique_id

  editors_group_id = var.editors_group_id
  network_cidr     = var.network_cidr
  subnet_cidr      = var.subnet_cidr
  tags             = var.tags
}

# =============================================================================
# CAST AI edge location and edge configurations.
# =============================================================================

module "edgelocation" {
  source = "./modules/edgelocation"

  name            = local.generated_name
  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  description     = var.description
  control_plane   = var.control_plane
  liqo            = var.liqo
  networking      = var.networking
  addons          = var.addons

  edge_configurations             = var.edge_configurations
  default_edge_configuration_name = var.default_edge_configuration_name

  wait_for_location_ready = var.wait_for_location_ready
  api_url                 = var.api_url
  api_token               = var.api_token

  # Nebius cloud resources (handoff bundle from the cloud submodule).
  parent_id          = var.parent_id
  region             = var.region
  service_account_id = module.cloud.nebius_resources.service_account_id
  network_id         = module.cloud.nebius_resources.network_id
  subnet_id          = module.cloud.nebius_resources.subnet_id
  subnet_cidr        = var.subnet_cidr
  security_group_id  = module.cloud.nebius_resources.security_group_id
}

# =============================================================================
# Moved blocks
# =============================================================================

# Preserve state compatibility for consumers of the pre-split module: the
# resources moved into the cloud / edgelocation submodules when the split
# ownership support was introduced. Without these, Terraform would plan a
# destroy and recreate of every resource for existing consumers.

moved {
  from = nebius_iam_v1_service_account.castai
  to   = module.cloud.nebius_iam_v1_service_account.castai
}

moved {
  from = nebius_iam_v1_federated_credentials.castai_wif
  to   = module.cloud.nebius_iam_v1_federated_credentials.castai_wif
}

moved {
  from = nebius_iam_v1_group.castai_editors
  to   = module.cloud.nebius_iam_v1_group.castai_editors
}

moved {
  from = nebius_iam_v1_access_permit.castai_editor
  to   = module.cloud.nebius_iam_v1_access_permit.castai_editor
}

moved {
  from = nebius_iam_v1_group_membership.castai
  to   = module.cloud.nebius_iam_v1_group_membership.castai
}

moved {
  from = nebius_vpc_v1_pool.main
  to   = module.cloud.nebius_vpc_v1_pool.main
}

moved {
  from = nebius_vpc_v1_network.main
  to   = module.cloud.nebius_vpc_v1_network.main
}

moved {
  from = nebius_vpc_v1_subnet.main
  to   = module.cloud.nebius_vpc_v1_subnet.main
}

moved {
  from = nebius_vpc_v1_security_group.main
  to   = module.cloud.nebius_vpc_v1_security_group.main
}

moved {
  from = nebius_vpc_v1_security_rule.ingress_self
  to   = module.cloud.nebius_vpc_v1_security_rule.ingress_self
}

moved {
  from = nebius_vpc_v1_security_rule.egress_all
  to   = module.cloud.nebius_vpc_v1_security_rule.egress_all
}

moved {
  from = castai_edge_location.this
  to   = module.edgelocation.castai_edge_location.this
}

moved {
  from = castai_edge_configuration.this
  to   = module.edgelocation.castai_edge_configuration.this
}

moved {
  from = castai_edge_configuration_default.this
  to   = module.edgelocation.castai_edge_configuration_default.this
}

moved {
  from = null_resource.castai_wait_for_location_ready
  to   = module.edgelocation.null_resource.castai_wait_for_location_ready
}
