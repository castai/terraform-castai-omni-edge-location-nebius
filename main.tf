# Nebius Edge Location for CAST AI

# Generate random suffix for edge location name
resource "random_id" "suffix" {
  byte_length = 4
}

# Read the Nebius project that owns the edge resources to validate that
# var.region matches the project's actual region (Nebius projects are created
# per region). Only read when the module provisions the cloud resources; in
# edge-location-only mode there is no Nebius access and the region comes from
# the handoff bundle instead.
data "nebius_iam_v2_project" "this" {
  count = var.provision_cloud ? 1 : 0

  id = var.parent_id
}

locals {
  # Region for the edge location. Always provided explicitly via var.region
  # (required); when the module provisions the cloud resources it is validated
  # against the Nebius project's actual region (see the precondition on the
  # service account below).
  region = var.region

  # WIF federated subject: the CAST AI GCP service account unique ID of the
  # Omni cluster. Provided directly (cloud-only mode, no CAST AI
  # credentials needed) or read from the castai_omni_cluster data source
  # (full mode). Null when the module does not provision cloud resources.
  oidc_subject_id = var.provision_cloud ? coalesce(var.castai_oidc_subject_id, try(data.castai_omni_cluster.this[0].castai_oidc_config.gcp_service_account_unique_id, null)) : null

  # Values for the castai_edge_location nebius block: module-created resources
  # when the module provisions the cloud resources, or the separately-provided
  # handoff bundle (var.existing_nebius_resources) in edge-location-only mode.
  edge_nebius = {
    parent_id          = var.parent_id
    service_account_id = var.provision_cloud ? nebius_iam_v1_service_account.castai[0].id : var.existing_nebius_resources.service_account_id
    network_id         = var.provision_cloud ? nebius_vpc_v1_network.main[0].id : var.existing_nebius_resources.network_id
    subnet_id          = var.provision_cloud ? nebius_vpc_v1_subnet.main[0].id : var.existing_nebius_resources.subnet_id
    subnet_cidr        = var.provision_cloud ? var.subnet_cidr : var.existing_nebius_resources.subnet_cidr
    security_group_id  = var.provision_cloud ? nebius_vpc_v1_security_group.main[0].id : var.existing_nebius_resources.security_group_id
  }

  # Generate name if not provided (with random suffix)
  generated_name = var.name != null ? var.name : "nebius-${var.region}-${random_id.suffix.hex}"

  # Sanitize name for Nebius resource naming (lowercase, alnum + hyphen).
  # replace() maps each character 1:1, so the sanitized length equals the input.
  sanitized_name = lower(replace(local.generated_name, "/[^a-zA-Z0-9-]/", "-"))

  # Nebius resource names are limited to 63 characters. short_resource_name is
  # prefixed with "castai-omni-" (12 chars) and reused with suffixes, the
  # longest being "-ingress-self" (13 chars). The sanitized core must therefore
  # be at most 63 - 12 - 13 = 38 chars. This is validated on var.name (see
  # variables.tf) and guarded by a precondition on the service account below
  # for the auto-generated (region-derived) path. No silent truncation - the
  # random suffix is always preserved in full.
  name_prefix               = "castai-omni-"
  sanitized_name_max_length = 63 - length(local.name_prefix) - length("-ingress-self")
  short_resource_name       = "${local.name_prefix}${local.sanitized_name}"

  # Resolve the editors group ID: use the user-provided group when set, or the
  # module-created dedicated group when editors_group_id is null. Null in
  # edge-location-only mode (no cloud resources are provisioned).
  editors_group_id = var.provision_cloud ? coalesce(var.editors_group_id, try(nebius_iam_v1_group.castai_editors[0].id, null)) : null

  # Common labels merged once and reused across all resources.
  # Nebius calls these `labels`; the module exposes them as `tags` for
  # consistency with the AWS / GCP / OCI sibling modules.
  common_labels = merge(
    var.tags,
    {
      "cast-omni:cluster-id" = var.cluster_id
    }
  )

  # Nebius regions are effectively single-zone for the v1 VPC API; expose the
  # region as a single availability zone for the castai_edge_location resource.
  zone = {
    id   = var.region
    name = var.region
  }

  default_description = "Nebius edge location onboarded by Terraform"
}

# Fetch CAST AI Omni cluster OIDC config. Used to model the impersonation
# contract between CAST AI and the Nebius service account.
# Only read when the module provisions the cloud resources and the WIF
# federated subject was not provided directly (var.castai_oidc_subject_id),
# so that cloud-only runs need no CAST AI credentials.
data "castai_omni_cluster" "this" {
  count = var.provision_cloud && var.castai_oidc_subject_id == null ? 1 : 0

  organization_id = var.organization_id
  cluster_id      = var.cluster_id
}

# Validation: ensure required variables are consistent.
resource "null_resource" "validate" {
  lifecycle {
    precondition {
      condition     = var.parent_id != null && var.parent_id != ""
      error_message = "parent_id (Nebius project ID) must be set."
    }
    precondition {
      condition     = var.provision_cloud || var.provision_edgelocation
      error_message = "At least one of provision_cloud or provision_edgelocation must be true."
    }
    precondition {
      condition     = var.provision_cloud || var.existing_nebius_resources != null
      error_message = "existing_nebius_resources must be set when provision_cloud is false (the handoff bundle from the run that provisioned the cloud resources)."
    }
  }
}

# =============================================================================
# IAM: Service account, WIF federated credentials, and group membership
# =============================================================================

# Service account that CAST AI will impersonate to manage Nebius resources.
resource "nebius_iam_v1_service_account" "castai" {
  count = var.provision_cloud ? 1 : 0

  parent_id   = var.parent_id
  name        = local.short_resource_name
  description = "Service account impersonated by CAST AI for edge location ${local.generated_name}"
  labels      = local.common_labels

  lifecycle {
    precondition {
      # Backstop for the auto-generated name (var.name == null): the region is
      # read from the Nebius project and could exceed the budget. User-provided
      # names are validated on var.name directly (see variables.tf).
      condition     = length(local.sanitized_name) <= local.sanitized_name_max_length
      error_message = "Generated resource name exceeds Nebius' 63-character limit; the auto-generated name is too long. Set var.name to a shorter value."
    }

    precondition {
      condition     = var.region == data.nebius_iam_v2_project.this[0].region
      error_message = "var.region (${var.region}) does not match the parent project's region (${data.nebius_iam_v2_project.this[0].region})."
    }
  }
}

# Workload Identity Federation (WIF): bind CAST AI's GCP OIDC identity to the
# Nebius service account so CAST AI can impersonate it via OIDC token exchange
# instead of static authorized-key credentials. The OIDC issuer is
# https://accounts.google.com (CAST AI runs on GCP) and the federated subject
# is the CAST AI GCP service account unique ID, read from the Omni cluster
# data source.
#
# jwk_set_json is set explicitly because the Nebius federated credentials
# feature is in PUBLIC PREVIEW: custom external OIDC providers with OIDC
# discovery are only available for early adopters, but providing the JWKS
# directly works without limitations. The JWKS is fetched from Google's
# public cert endpoint at plan time.
data "http" "google_jwks" {
  count = var.provision_cloud ? 1 : 0

  url = "https://www.googleapis.com/oauth2/v3/certs"
}

resource "nebius_iam_v1_federated_credentials" "castai_wif" {
  count = var.provision_cloud ? 1 : 0

  parent_id  = var.parent_id
  name       = "${local.short_resource_name}-wif"
  subject_id = nebius_iam_v1_service_account.castai[0].id

  oidc_provider = {
    issuer_url   = "https://accounts.google.com"
    jwk_set_json = data.http.google_jwks[0].response_body
  }

  federated_subject_id = local.oidc_subject_id

  labels = local.common_labels
}

# =============================================================================
# IAM: Editor group and group membership
# =============================================================================

# When editors_group_id is not provided, create a dedicated IAM group for this
# edge location. The group is granted the editor role on the project below.
resource "nebius_iam_v1_group" "castai_editors" {
  count = var.provision_cloud && var.editors_group_id == null ? 1 : 0

  parent_id = var.parent_id
  name      = "${local.short_resource_name}-editors"
  labels    = local.common_labels
}

# Grant the editor role on the project to the dedicated group. The editor role
# allows managing compute instances, disks, and networking resources.
resource "nebius_iam_v1_access_permit" "castai_editor" {
  count = var.provision_cloud && var.editors_group_id == null ? 1 : 0

  parent_id   = nebius_iam_v1_group.castai_editors[0].id
  resource_id = var.parent_id
  role        = "editor"
}

# Add the service account to the editors group so it can manage compute
# instances, disks and networking. Uses the user-provided group when set, or
# the module-created dedicated group when editors_group_id is null.
resource "nebius_iam_v1_group_membership" "castai" {
  count = var.provision_cloud ? 1 : 0

  parent_id = local.editors_group_id
  member_id = nebius_iam_v1_service_account.castai[0].id
}

# =============================================================================
# VPC Network and Subnet
# =============================================================================

# Address pool carrying the user-provided network CIDR. The network references
# this pool so its address space is defined by var.network_cidr rather than a
# random default. The subnet uses a specific CIDR (var.subnet_cidr) carved from
# this pool.
resource "nebius_vpc_v1_pool" "main" {
  count = var.provision_cloud ? 1 : 0

  parent_id  = var.parent_id
  name       = local.short_resource_name
  labels     = local.common_labels
  version    = "IPV4"
  visibility = "PRIVATE"

  cidrs = [
    {
      cidr = var.network_cidr
    }
  ]
}

# VPC network that will host edge instances. References the address pool so the
# network's address space is defined by var.network_cidr (not a random default).
resource "nebius_vpc_v1_network" "main" {
  count = var.provision_cloud ? 1 : 0

  parent_id = var.parent_id
  name      = local.short_resource_name
  labels    = local.common_labels

  ipv4_private_pools = {
    pools = [
      { id = nebius_vpc_v1_pool.main[0].id }
    ]
  }
}

# Regional private subnet for edge instances. Uses an explicit CIDR
# (var.subnet_cidr) that must be within the network's address space
# (var.network_cidr). max_mask_length constrains allocations from this subnet.
resource "nebius_vpc_v1_subnet" "main" {
  count = var.provision_cloud ? 1 : 0

  parent_id  = var.parent_id
  network_id = nebius_vpc_v1_network.main[0].id
  name       = local.short_resource_name
  labels     = local.common_labels

  ipv4_private_pools = {
    use_network_pools = false
    pools = [
      {
        cidrs = [
          {
            cidr = var.subnet_cidr
          }
        ]
      }
    ]
  }
}

# =============================================================================
# Security Group and Rules
# =============================================================================

# Security group bound to the edge network.
resource "nebius_vpc_v1_security_group" "main" {
  count = var.provision_cloud ? 1 : 0

  parent_id  = var.parent_id
  network_id = nebius_vpc_v1_network.main[0].id
  name       = local.short_resource_name
  labels     = local.common_labels
}

# Ingress: allow all traffic between instances in the same security group.
# For a security rule, `parent_id` is the security group the rule belongs to.
resource "nebius_vpc_v1_security_rule" "ingress_self" {
  count = var.provision_cloud ? 1 : 0

  parent_id = nebius_vpc_v1_security_group.main[0].id
  name      = "${local.short_resource_name}-ingress-self"
  access    = "ALLOW"
  protocol  = "ANY"
  labels    = local.common_labels

  ingress = {
    source_security_group_id = nebius_vpc_v1_security_group.main[0].id
  }
}

# Egress: allow all outbound traffic.
resource "nebius_vpc_v1_security_rule" "egress_all" {
  count = var.provision_cloud ? 1 : 0

  parent_id = nebius_vpc_v1_security_group.main[0].id
  name      = "${local.short_resource_name}-egress-all"
  access    = "ALLOW"
  protocol  = "ANY"
  labels    = local.common_labels

  egress = {
    destination_cidrs = ["0.0.0.0/0"]
  }
}

# =============================================================================
# CAST AI Edge Location
# =============================================================================

resource "castai_edge_location" "this" {
  count = var.provision_edgelocation ? 1 : 0

  name               = local.generated_name
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
  # the impersonation is enabled by the WIF federated credentials created
  # above (nebius_iam_v1_federated_credentials.castai_wif), so no static
  # authorized-key credentials are passed to CAST AI. In edge-location-only
  # mode the values come from the handoff bundle provided by the owner of
  # the cloud resources (var.existing_nebius_resources); see local.edge_nebius.
  nebius = local.edge_nebius

  depends_on = [
    nebius_iam_v1_federated_credentials.castai_wif,
    nebius_iam_v1_access_permit.castai_editor,
    nebius_iam_v1_group_membership.castai,
    nebius_vpc_v1_security_rule.ingress_self,
    nebius_vpc_v1_security_rule.egress_all,
  ]
}

# =============================================================================
# CAST AI Edge Configuration (Nebius)
# =============================================================================

resource "castai_edge_configuration" "this" {
  for_each = var.provision_edgelocation ? var.edge_configurations : {}

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this[0].id
  name             = each.value.name
  user_data_base64 = each.value.user_data_base64
  cri              = each.value.cri

  # NOTE: the `nebius` block on castai_edge_configuration is assumed for this
  # draft and mirrors the structure of the existing `aws` / `gcp` / `oci` blocks.
  nebius = {
    image_id           = try(each.value.image_id, null)
    boot_disk_size_gib = try(each.value.boot_disk_size_gib, null)
    labels             = try(each.value.labels, {})
    reservation_ids    = try(each.value.reservation_ids, null)
    gpu_cluster        = try(each.value.gpu_cluster, null)
  }
}

resource "castai_edge_configuration_default" "this" {
  count = var.provision_edgelocation && var.default_edge_configuration_name != "" ? 1 : 0

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this[0].id
  configuration_id = castai_edge_configuration.this[var.default_edge_configuration_name].id
}

resource "null_resource" "castai_wait_for_location_ready" {
  count      = var.provision_edgelocation && var.wait_for_location_ready ? 1 : 0
  depends_on = [castai_edge_location.this]

  provisioner "local-exec" {
    environment = {
      API_KEY = var.api_token
    }
    command = <<-EOT
        RETRY_COUNT=20
        POLLING_INTERVAL=30
        URL="${var.api_url}/omni-provisioner/v1beta/organizations/${var.organization_id}/clusters/${var.cluster_id}/edge-locations/${castai_edge_location.this[0].id}"
                                                                                                                                                                                                                                                                                                     
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

# =============================================================================
# Moved blocks
# =============================================================================

# Preserve state compatibility for resources that gained a `count` when the
# cloud / edge-location ownership toggles (provision_cloud /
# provision_edgelocation) were introduced: without these, Terraform would
# plan a destroy and recreate of every cloud resource for existing consumers.

moved {
  from = nebius_iam_v1_service_account.castai
  to   = nebius_iam_v1_service_account.castai[0]
}

moved {
  from = nebius_iam_v1_federated_credentials.castai_wif
  to   = nebius_iam_v1_federated_credentials.castai_wif[0]
}

moved {
  from = nebius_iam_v1_group_membership.castai
  to   = nebius_iam_v1_group_membership.castai[0]
}

moved {
  from = nebius_vpc_v1_pool.main
  to   = nebius_vpc_v1_pool.main[0]
}

moved {
  from = nebius_vpc_v1_network.main
  to   = nebius_vpc_v1_network.main[0]
}

moved {
  from = nebius_vpc_v1_subnet.main
  to   = nebius_vpc_v1_subnet.main[0]
}

moved {
  from = nebius_vpc_v1_security_group.main
  to   = nebius_vpc_v1_security_group.main[0]
}

moved {
  from = nebius_vpc_v1_security_rule.ingress_self
  to   = nebius_vpc_v1_security_rule.ingress_self[0]
}

moved {
  from = nebius_vpc_v1_security_rule.egress_all
  to   = nebius_vpc_v1_security_rule.egress_all[0]
}

moved {
  from = castai_edge_location.this
  to   = castai_edge_location.this[0]
}
