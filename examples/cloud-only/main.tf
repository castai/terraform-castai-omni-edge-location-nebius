# =============================================================================
# Cloud-resources-only mode: provision only the Nebius cloud resources.
#
# Use this mode when the cloud resources and the edge location are owned by
# different parties. The two runs exchange data:
#
#   1. edge location owner -> cloud resources owner: castai_oidc_subject_id
#      (a single string read from the castai_omni_cluster data source)
#   2. cloud resources owner -> edge location owner: the nebius_resources
#      output of this run
# =============================================================================

module "castai_nebius_edge_cloud" {
  source = "../.."

  provision_edgelocation = false

  organization_id = var.organization_id
  cluster_id      = var.cluster_id

  # Nebius project that owns the edge cloud resources, and its region
  # (validated against the project's actual region).
  parent_id = var.nebius_project_id
  region    = var.region

  # WIF federated subject: the Omni cluster's CAST AI OIDC identity. With
  # this set, the module reads no CAST AI data in this run.
  castai_oidc_subject_id = var.castai_oidc_subject_id

  editors_group_id = var.editors_group_id

  name         = var.name
  network_cidr = var.network_cidr
  subnet_cidr  = var.subnet_cidr

  tags = var.tags
}
