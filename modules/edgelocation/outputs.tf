output "edge_location_id" {
  description = "CAST AI edge location ID"
  value       = castai_edge_location.this.id
}

output "edge_location_name" {
  description = "CAST AI edge location name"
  value       = castai_edge_location.this.name
}

output "edge_configuration_ids" {
  description = "Map of edge configuration IDs by configuration key"
  value = {
    for k, v in castai_edge_configuration.this : k => v.id
  }
}
