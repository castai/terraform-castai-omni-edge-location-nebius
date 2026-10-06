output "nebius_resources" {
  description = "Handoff bundle for the owner of the edge location: everything needed to configure the castai_edge_location nebius block (either via the edgelocation submodule or with the raw resource)"
  value       = module.castai_nebius_edge_cloud.nebius_resources
}
