output "edge_location_id" {
  description = "CAST AI edge location ID"
  value       = module.edgelocation.edge_location_id
}

output "edge_location_name" {
  description = "CAST AI edge location name"
  value       = module.edgelocation.edge_location_name
}

output "nebius_resources" {
  description = "Nebius resources created for the edge location, including everything needed to configure a castai_edge_location (nebius block) directly"
  value       = module.cloud.nebius_resources
}

output "nebius_federated_credentials_id" {
  description = "ID of the Nebius WIF federated credentials binding CAST AI's GCP OIDC identity to the service account"
  value       = module.cloud.nebius_resources.federated_credentials_id
}

output "edge_configuration_ids" {
  description = "Map of edge configuration IDs by configuration key"
  value       = module.edgelocation.edge_configuration_ids
}

output "debug_gcp_sa_email" {
  value = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_email
}

output "debug_gcp_sa_unique_id" {
  value = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_unique_id
}
