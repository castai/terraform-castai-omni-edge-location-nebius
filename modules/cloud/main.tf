# Nebius cloud resources for a CAST AI edge location.
#
# This submodule provisions only the Nebius side (IAM, WIF, VPC) and requires
# only Nebius credentials. Use it directly when the cloud resources and the
# edge location are owned by different parties: the owner of the edge location
# provides castai_oidc_subject_id, and this module's nebius_resources output is
# the handoff bundle for the edge location (see the edgelocation submodule).

# Read the Nebius project that owns the edge resources to validate that
# var.region matches the project's actual region (Nebius projects are created
# per region).
data "nebius_iam_v2_project" "this" {
  id = var.parent_id
}

locals {
  # Sanitize name for Nebius resource naming (lowercase, alnum + hyphen).
  # replace() maps each character 1:1, so the sanitized length equals the input.
  sanitized_name = lower(replace(var.name, "/[^a-zA-Z0-9-]/", "-"))

  # Nebius resource names are limited to 63 characters. short_resource_name is
  # prefixed with "castai-omni-" (12 chars) and reused with suffixes, the
  # longest being "-ingress-self" (13 chars). The sanitized core must therefore
  # be at most 63 - 12 - 13 = 38 chars, which is validated on var.name (see
  # variables.tf). No silent truncation.
  name_prefix         = "castai-omni-"
  short_resource_name = "${local.name_prefix}${local.sanitized_name}"

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
}

# =============================================================================
# IAM: Service account, WIF federated credentials, and group membership
# =============================================================================

# Service account that CAST AI will impersonate to manage Nebius resources.
resource "nebius_iam_v1_service_account" "castai" {
  parent_id   = var.parent_id
  name        = local.short_resource_name
  description = "Service account impersonated by CAST AI for edge location ${var.name}"
  labels      = local.common_labels

  lifecycle {
    precondition {
      condition     = var.region == data.nebius_iam_v2_project.this.region
      error_message = "var.region (${var.region}) does not match the parent project's region (${data.nebius_iam_v2_project.this.region})."
    }
  }
}

# Workload Identity Federation (WIF): bind CAST AI's GCP OIDC identity to the
# Nebius service account so CAST AI can impersonate it via OIDC token exchange
# instead of static authorized-key credentials. The OIDC issuer is
# https://accounts.google.com (CAST AI runs on GCP) and the federated subject
# is the CAST AI GCP service account unique ID, provided via
# var.castai_oidc_subject_id.
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

  federated_subject_id = var.castai_oidc_subject_id

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
