output "nebius_resources" {
  description = "Handoff bundle of Nebius resources created for the edge location, including everything needed to configure a castai_edge_location (nebius block) directly. This is what the owner of the edge location consumes when the cloud resources and the edge location are owned by different parties."
  value = {
    name                     = var.name
    parent_id                = var.parent_id
    region                   = var.region
    service_account_id       = nebius_iam_v1_service_account.castai.id
    network_id               = nebius_vpc_v1_network.main.id
    subnet_id                = nebius_vpc_v1_subnet.main.id
    subnet_cidr              = var.subnet_cidr
    security_group_id        = nebius_vpc_v1_security_group.main.id
    federated_credentials_id = nebius_iam_v1_federated_credentials.castai_wif.id
    editors_group_id         = local.editors_group_id
    editors_access_permit_id = try(nebius_iam_v1_access_permit.castai_editor[0].id, null)
  }
}

output "nebius_federated_credentials_id" {
  description = "ID of the Nebius WIF federated credentials binding CAST AI's GCP OIDC identity to the service account"
  value       = nebius_iam_v1_federated_credentials.castai_wif.id
}
