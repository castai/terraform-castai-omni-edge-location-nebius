module "castai_nebius_edge_location" {
  source = "../.."

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  # Nebius project ID that will own the edge location resources, and its
  # region (validated against the project's actual region).
  parent_id = var.parent_id
  region    = var.region

  name          = var.name
  description   = var.description
  control_plane = var.control_plane
  liqo          = var.liqo
}
