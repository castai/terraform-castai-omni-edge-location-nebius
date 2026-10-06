output "edge_location_id" {
  description = "CAST AI edge location ID (null when provision_edgelocation is false)"
  value       = var.provision_edgelocation ? castai_edge_location.this[0].id : null
}

output "edge_location_name" {
  description = "CAST AI edge location name (null when provision_edgelocation is false)"
  value       = var.provision_edgelocation ? castai_edge_location.this[0].name : null
}

output "nebius_resources" {
  description = "Nebius resources created for the edge location, including everything needed to configure a castai_edge_location (nebius block) directly. This is the handoff bundle for the edge location owner when the cloud resources are provisioned separately. Null when provision_cloud is false."
  value = var.provision_cloud ? {
    parent_id                = var.parent_id
    region                   = local.region
    service_account_id       = nebius_iam_v1_service_account.castai[0].id
    network_id               = nebius_vpc_v1_network.main[0].id
    subnet_id                = nebius_vpc_v1_subnet.main[0].id
    subnet_cidr              = var.subnet_cidr
    security_group_id        = nebius_vpc_v1_security_group.main[0].id
    federated_credentials_id = nebius_iam_v1_federated_credentials.castai_wif[0].id
    editors_group_id         = local.editors_group_id
    editors_access_permit_id = try(nebius_iam_v1_access_permit.castai_editor[0].id, null)
    network_id               = nebius_vpc_v1_network.main.id
    subnet_id                = nebius_vpc_v1_subnet.main.id
    security_group_id        = nebius_vpc_v1_security_group.main.id
  } : null
}

output "nebius_federated_credentials_id" {
  description = "ID of the Nebius WIF federated credentials binding CAST AI's GCP OIDC identity to the service account (null when provision_cloud is false)"
  value       = var.provision_cloud ? nebius_iam_v1_federated_credentials.castai_wif[0].id : null
}

output "edge_configuration_ids" {
  description = "Map of edge configuration IDs by configuration key"
  value = {
    for k, v in castai_edge_configuration.this : k => v.id
  }
}

output "debug_gcp_sa_email" {
  description = "CAST AI GCP service account email of the Omni cluster (only read when the module resolves the WIF subject via the castai_omni_cluster data source)"
  value       = try(data.castai_omni_cluster.this[0].castai_oidc_config.gcp_service_account_email, null)
}

output "debug_gcp_sa_unique_id" {
  description = "CAST AI GCP service account unique ID of the Omni cluster (only read when the module resolves the WIF subject via the castai_omni_cluster data source)"
  value       = try(data.castai_omni_cluster.this[0].castai_oidc_config.gcp_service_account_unique_id, null)
}
