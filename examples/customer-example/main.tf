# =============================================================================
# Example: edge-location-only mode using the edgelocation submodule.
#
# The Nebius cloud resources were provisioned separately (see the cloud-only
# example) and are referenced via the handoff bundle; no Nebius credentials
# are required.
#
# This example shows the additional knobs the edge location supports:
#   - explicit addons (only nvidia-gpu-operator)
#   - external LoadBalancer overrides for the control plane and the Liqo
#     gateway (var.load_balancer_overrides)
#   - GPU edge configurations (var.edge_configurations)
# =============================================================================

module "castai_nebius_edge_location" {
  # Fully-qualified Terraform Registry source: the module is published as
  # castai/omni-edge-location-nebius/castai, and this example uses its
  # edgelocation submodule. No local checkout of the module is required.
  source  = "castai/omni-edge-location-nebius/castai//modules/edgelocation"
  version = "~> 1.1"

  # CAST AI variables
  api_token       = var.castai_api_token
  api_url         = var.castai_api_url
  organization_id = var.organization_id
  cluster_id      = var.cluster_id

  name        = var.name
  description = var.description

  # Handoff bundle from the cloud-resources owned by CastAI.
  parent_id          = var.nebius_handoff.parent_id
  region             = var.nebius_handoff.region
  service_account_id = var.nebius_handoff.service_account_id
  network_id         = var.nebius_handoff.network_id
  subnet_id          = var.nebius_handoff.subnet_id
  subnet_cidr        = var.nebius_handoff.subnet_cidr
  security_group_id  = var.nebius_handoff.security_group_id

  addons = [
    {
      name = "nvidia-gpu-operator"
    }
  ]

  # External LoadBalancer overrides for the API server: the control plane is reached through
  # the Azure firewall, and its in-cluster LoadBalancer uses the KMC internal IP.
  control_plane = {
    ha               = true
    external_address = var.firewall_overrides.azure_firewall_ip
    service_annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
      "service.beta.kubernetes.io/azure-load-balancer-ipv4"     = var.firewall_overrides.kmc_internal_lb_ip
    }
  }

  # External LoadBalancer overrides for the Liqo gateway: same Azure firewall, with the Liqo internal LoadBalancer IP.
  liqo = {
    gateway_server = {
      external_address = var.firewall_overrides.azure_firewall_ip
      service_annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
        "service.beta.kubernetes.io/azure-load-balancer-ipv4"     = var.firewall_overrides.liqo_internal_lb_ip
      }
    }
  }

  # Edge configurations.
  edge_configurations = {
    b200_nebius_me_west1 = {
      name               = "b200-nebius-me-west1"
      boot_disk_size_gib = 2000
      image_id           = var.ec_b200_nebius_me_west1.image_id
      reservation_ids    = var.ec_b200_nebius_me_west1.reservation_ids
      gpu_cluster        = var.ec_b200_nebius_me_west1.gpu_cluster_id
    }
  }
}
