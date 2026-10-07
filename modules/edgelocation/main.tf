# CAST AI edge location on Nebius.
#
# This submodule provisions only the CAST AI side (edge location and edge
# configurations) and requires only CAST AI credentials. Use it directly when
# the cloud resources and the edge location are owned by different parties:
# the nebius_* inputs come from the cloud submodule's nebius_resources output
# (the handoff bundle).

locals {
  # Nebius regions are effectively single-zone for the v1 VPC API; expose the
  # region as a single availability zone for the castai_edge_location resource.
  zone = {
    id   = var.region
    name = var.region
  }

  default_description = "Nebius edge location onboarded by Terraform"
}

# =============================================================================
# CAST AI Edge Location
# =============================================================================

resource "castai_edge_location" "this" {
  name               = var.name
  region             = var.region
  cluster_id         = var.cluster_id
  organization_id    = var.organization_id
  description        = var.description != null ? var.description : local.default_description
  control_plane      = var.control_plane
  control_plane_mode = "SHARED"
  networking         = var.networking
  liqo               = var.liqo
  addons             = var.addons

  zones = [local.zone]

  # Nebius cloud provider configuration (castai provider >= 9.6.3 schema).
  # CAST AI impersonates the service account referenced by service_account_id;
  # the impersonation is enabled by the WIF federated credentials created by
  # the cloud submodule, so no static authorized-key credentials are passed
  # to CAST AI.
  nebius = {
    parent_id          = var.parent_id
    service_account_id = var.service_account_id
    network_id         = var.network_id
    subnet_id          = var.subnet_id
    subnet_cidr        = var.subnet_cidr
    security_group_id  = var.security_group_id
  }
}

# =============================================================================
# CAST AI Edge Configuration (Nebius)
# =============================================================================

resource "castai_edge_configuration" "this" {
  for_each = var.edge_configurations

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this.id
  name             = each.value.name
  user_data_base64 = each.value.user_data_base64
  cri              = each.value.cri

  nebius = {
    image_id           = try(each.value.image_id, null)
    boot_disk_size_gib = try(each.value.boot_disk_size_gib, null)
    labels             = try(each.value.labels, {})
    reservation_ids    = try(each.value.reservation_ids, null)
    gpu_cluster        = try(each.value.gpu_cluster, null)
  }
}

resource "castai_edge_configuration_default" "this" {
  count = var.default_edge_configuration_name != "" ? 1 : 0

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this.id
  configuration_id = castai_edge_configuration.this[var.default_edge_configuration_name].id
}

resource "null_resource" "castai_wait_for_location_ready" {
  count      = var.wait_for_location_ready ? 1 : 0
  depends_on = [castai_edge_location.this]

  provisioner "local-exec" {
    environment = {
      API_KEY = var.api_token
    }
    command = <<-EOT
        RETRY_COUNT=20
        POLLING_INTERVAL=30
        URL="${var.api_url}/omni-provisioner/v1beta/organizations/${var.organization_id}/clusters/${var.cluster_id}/edge-locations/${castai_edge_location.this.id}"

        for i in $(seq 1 $RETRY_COUNT); do
          sleep $POLLING_INTERVAL

          RESPONSE=$(curl -s "$URL" -H "x-api-key: $API_KEY")

          if echo "$RESPONSE" | grep -iE '"state"[[:space:]]*:[[:space:]]*"ready"'; then
            echo "Edge location is ready"
            exit 0
          fi

        done

        echo "Edge location is not ready after 10 minutes"
        exit 1
    EOT

    interpreter = ["bash", "-c"]
  }
}
