# Nebius Edge Location for CAST AI

# Generate random suffix for edge location name
resource "random_id" "suffix" {
  byte_length = 4
}

# Look up the Nebius project that owns the edge resources. Nebius projects are
# created per region, so the project's region is derived here rather than
# asked of the user separately.
data "nebius_iam_v2_project" "this" {
  id = var.parent_id
}

locals {
  # Generate name if not provided (with random suffix)
  generated_name = var.name != null ? var.name : "nebius-${data.nebius_iam_v2_project.this.region}-${random_id.suffix.hex}"

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
  # module-created dedicated group when editors_group_id is null.
  editors_group_id = coalesce(var.editors_group_id, try(nebius_iam_v1_group.castai_editors[0].id, null))

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
    id   = data.nebius_iam_v2_project.this.region
    name = data.nebius_iam_v2_project.this.region
  }

  default_description = "Nebius edge location onboarded by Terraform"
}

# Fetch CAST AI Omni cluster OIDC config. Used to model the impersonation
# contract between CAST AI and the customer's Nebius service account.
data "castai_omni_cluster" "this" {
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
  }
}

# =============================================================================
# IAM: Service account, WIF federated credentials, and group membership
# =============================================================================

# Service account that CAST AI will impersonate to manage Nebius resources.
resource "nebius_iam_v1_service_account" "castai" {
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
  url = "https://www.googleapis.com/oauth2/v3/certs"
}

resource "nebius_iam_v1_federated_credentials" "castai_wif" {
  parent_id  = var.parent_id
  name       = "${local.short_resource_name}-wif"
  subject_id = nebius_iam_v1_service_account.castai.id

  oidc_provider = {
    issuer_url   = "https://accounts.google.com"
    jwk_set_json = data.http.google_jwks.response_body
  }

  federated_subject_id = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_unique_id

  labels = local.common_labels
}

# =============================================================================
# IAM: Editor group and group membership
# =============================================================================

# When editors_group_id is not provided, create a dedicated IAM group for this
# edge location. The group is granted the editor role on the project below.
resource "nebius_iam_v1_group" "castai_editors" {
  count = var.editors_group_id != null ? 0 : 1

  parent_id = var.parent_id
  name      = "${local.short_resource_name}-editors"
  labels    = local.common_labels
}

# Grant the editor role on the project to the dedicated group. The editor role
# allows managing compute instances, disks, and networking resources.
resource "nebius_iam_v1_access_permit" "castai_editor" {
  count = var.editors_group_id != null ? 0 : 1

  parent_id   = nebius_iam_v1_group.castai_editors[0].id
  resource_id = var.parent_id
  role        = "editor"
}

# Add the service account to the editors group so it can manage compute
# instances, disks and networking. Uses the user-provided group when set, or
# the module-created dedicated group when editors_group_id is null.
resource "nebius_iam_v1_group_membership" "castai" {
  parent_id = local.editors_group_id
  member_id = nebius_iam_v1_service_account.castai.id
}

# =============================================================================
# VPC Network and Subnet
# =============================================================================

# Address pool carrying the user-provided network CIDR. The network references
# this pool so its address space is defined by var.network_cidr rather than a
# random default. The subnet uses a specific CIDR (var.subnet_cidr) carved from
# this pool.
resource "nebius_vpc_v1_pool" "main" {
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
  parent_id = var.parent_id
  name      = local.short_resource_name
  labels    = local.common_labels

  ipv4_private_pools = {
    pools = [
      { id = nebius_vpc_v1_pool.main.id }
    ]
  }
}

# Regional private subnet for edge instances. Uses an explicit CIDR
# (var.subnet_cidr) that must be within the network's address space
# (var.network_cidr). max_mask_length constrains allocations from this subnet.
resource "nebius_vpc_v1_subnet" "main" {
  parent_id  = var.parent_id
  network_id = nebius_vpc_v1_network.main.id
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
  parent_id  = var.parent_id
  network_id = nebius_vpc_v1_network.main.id
  name       = local.short_resource_name
  labels     = local.common_labels
}

# Ingress: allow all traffic between instances in the same security group.
# For a security rule, `parent_id` is the security group the rule belongs to.
resource "nebius_vpc_v1_security_rule" "ingress_self" {
  parent_id = nebius_vpc_v1_security_group.main.id
  name      = "${local.short_resource_name}-ingress-self"
  access    = "ALLOW"
  protocol  = "ANY"
  labels    = local.common_labels

  ingress = {
    source_security_group_id = nebius_vpc_v1_security_group.main.id
  }
}

# Egress: allow all outbound traffic.
resource "nebius_vpc_v1_security_rule" "egress_all" {
  parent_id = nebius_vpc_v1_security_group.main.id
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
  name               = local.generated_name
  region             = data.nebius_iam_v2_project.this.region
  cluster_id         = var.cluster_id
  organization_id    = var.organization_id
  description        = var.description != null ? var.description : local.default_description
  control_plane      = var.control_plane
  control_plane_mode = "SHARED"
  networking         = var.networking
  addons             = var.addons

  zones = [local.zone]

  # Nebius cloud provider configuration.
  # The nebius block conforms to the castai/castai provider schema at commit
  # 78331cf (WIF). target_service_account_id enables WIF (OIDC token exchange)
  # instead of static authorized-key credentials. Both service_account_id and
  # target_service_account_id point to the same module-created service account.
  nebius = {
    parent_id                 = var.parent_id
    service_account_id        = nebius_iam_v1_service_account.castai.id
    target_service_account_id = nebius_iam_v1_service_account.castai.id
    network_id                = nebius_vpc_v1_network.main.id
    subnet_id                 = nebius_vpc_v1_subnet.main.id
    subnet_cidr               = var.subnet_cidr
    security_group_id         = nebius_vpc_v1_security_group.main.id
  }

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
  for_each = var.edge_configurations

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this.id
  name             = each.value.name
  user_data_base64 = each.value.user_data_base64
  cri              = each.value.cri

  # NOTE: the `nebius` block on castai_edge_configuration is assumed for this
  # draft and mirrors the structure of the existing `aws` / `gcp` / `oci` blocks.
  nebius = {
    image_id           = try(each.value.image_id, null)
    boot_disk_size_gib = try(each.value.boot_disk_size_gib, null)
    labels             = try(each.value.labels, {})
  }
}

resource "castai_edge_configuration_default" "this" {
  count = var.default_edge_configuration_name != "" ? 1 : 0

  organization_id  = var.organization_id
  cluster_id       = var.cluster_id
  edge_location_id = castai_edge_location.this.id
  configuration_id = castai_edge_configuration.this[var.default_edge_configuration_name].id
}
