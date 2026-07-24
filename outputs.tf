output "edge_location_id" {
  description = "CAST AI edge location ID"
  value       = castai_edge_location.this.id
}

output "edge_location_name" {
  description = "CAST AI edge location name"
  value       = castai_edge_location.this.name
}

output "nebius_resources" {
  description = "Nebius resources created for the edge location"
  value = {
    parent_id          = var.parent_id
    service_account_id = nebius_iam_v1_service_account.castai.id
    authorized_key_id  = nebius_iam_v1_auth_public_key.castai.id
    network_id         = nebius_vpc_v1_network.main.id
    subnet_id          = nebius_vpc_v1_subnet.main.id
    security_group_id  = nebius_vpc_v1_security_group.main.id
  }
}

output "edge_configuration_ids" {
  description = "Map of edge configuration IDs by configuration key"
  value = {
    for k, v in castai_edge_configuration.this : k => v.id
  }
}
