module "castai_nebius_edge_location" {
  source = "../.."

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  # Nebius project ID that will own the edge location resources. The project's
  # region is read automatically and used as the edge location region, so no
  # separate region input is required.
  parent_id = var.parent_id

  name          = var.name
  description   = var.description
  control_plane = var.control_plane
  liqo          = var.liqo
}
