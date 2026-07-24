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

  # Sanitize name for Nebius resource naming (lowercase, alnum + hyphen)
  sanitized_name = lower(replace(local.generated_name, "/[^a-zA-Z0-9-]/", "-"))

  # Full resource name with prefix
  resource_name = "castai-omni-${local.sanitized_name}"

  # Nebius resource names have a 63-char limit; trim to be safe.
  short_resource_name = substr(local.resource_name, 0, 63)

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
# IAM: Service account, authorized key, and group membership
# =============================================================================

# Service account that CAST AI will impersonate to manage Nebius resources.
resource "nebius_iam_v1_service_account" "castai" {
  parent_id   = var.parent_id
  name        = local.short_resource_name
  description = "Service account impersonated by CAST AI for edge location ${local.generated_name}"
  labels      = local.common_labels
}

# RSA key pair used as the authorized key for the service account.
resource "tls_private_key" "castai_authorized_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload the public key to the service account as an authorized key.
resource "nebius_iam_v1_auth_public_key" "castai" {
  parent_id = var.parent_id
  name      = "${local.short_resource_name}-auth-key"

  account = {
    service_account = {
      id = nebius_iam_v1_service_account.castai.id
    }
  }

  data = trimspace(tls_private_key.castai_authorized_key.public_key_pem)
}

# Add the service account to the project's `editors` group so it can manage
# compute instances, disks and networking. Optional: if editors_group_id is
# not provided, permissions must be granted out-of-band.
resource "nebius_iam_v1_group_membership" "castai" {
  count = var.editors_group_id != null ? 1 : 0

  parent_id = var.editors_group_id
  member_id = nebius_iam_v1_service_account.castai.id
}

# =============================================================================
# VPC Network and Subnet
# =============================================================================

# VPC network that will host edge instances.
resource "nebius_vpc_v1_network" "main" {
  parent_id = var.parent_id
  name      = local.short_resource_name
  labels    = local.common_labels
}

# Regional private subnet for edge instances.
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
          { cidr = var.subnet_cidr }
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
  # NOTE: the `nebius` block on castai_edge_location is assumed for this draft
  # and mirrors the structure of the existing `aws` / `gcp` / `oci` blocks.
  nebius = {
    parent_id             = var.parent_id
    service_account_id    = nebius_iam_v1_service_account.castai.id
    authorized_key_id_wo  = nebius_iam_v1_auth_public_key.castai.id
    private_key_base64_wo = base64encode(tls_private_key.castai_authorized_key.private_key_pem)
    network_id            = nebius_vpc_v1_network.main.id
    subnet_id             = nebius_vpc_v1_subnet.main.id
    subnet_cidr           = var.subnet_cidr
    security_group_id     = nebius_vpc_v1_security_group.main.id
  }

  depends_on = [
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
