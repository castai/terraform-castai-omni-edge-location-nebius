output "nebius_resources" {
  description = "Handoff bundle for the owner of the edge location: everything needed to configure the castai_edge_location nebius block (either via this module in edge-location-only mode or with the raw resource)"
  value       = module.castai_nebius_edge_cloud.nebius_resources
}
