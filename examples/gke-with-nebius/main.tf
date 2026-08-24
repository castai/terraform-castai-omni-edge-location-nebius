data "google_project" "current" {}

data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = data.google_project.current.project_id
}

# =============================================================================
# Onboard cluster to CAST AI
# =============================================================================

module "castai_gke_iam" {
  source  = "castai/gke-iam/castai"
  version = "~> 0.5"

  project_id       = data.google_project.current.project_id
  gke_cluster_name = var.gke_cluster_name
}

module "castai_gke_cluster" {
  source  = "castai/gke-cluster/castai"
  version = "~> 10"

  api_url          = var.castai_api_url
  castai_api_token = var.castai_api_token

  project_id           = data.google_project.current.project_id
  gke_cluster_name     = var.gke_cluster_name
  gke_cluster_location = var.gke_cluster_location
  gke_credentials      = module.castai_gke_iam.private_key

  default_node_configuration_name = "default"
  node_configurations = {
    default = {
      subnets = [data.google_container_cluster.gke.subnetwork]
    }
  }

  wait_for_cluster_ready = true
}

# =============================================================================
# Onboarding OMNI and creating a location.
# =============================================================================

locals {
  # The subnetwork can be a full path like "projects/PROJECT/regions/REGION/subnetworks/SUBNET"
  # or just the subnet name
  subnet_name = element(reverse(split("/", data.google_container_cluster.gke.subnetwork)), 0)

  # Determine region from location (if zonal, extract region; if regional, use as-is)
  is_zonal_cluster = length(regexall("^.*-[a-z]$", var.gke_cluster_location)) > 0
  cluster_region   = local.is_zonal_cluster ? regex("^(.*)-[a-z]$", var.gke_cluster_location)[0] : var.gke_cluster_location

  pod_cidrs = distinct(concat(
    [data.google_container_cluster.gke.cluster_ipv4_cidr],
    [
      for nc in flatten(data.google_container_cluster.gke.node_pool[*].network_config) : nc.pod_ipv4_cidr_block
      if nc.pod_ipv4_cidr_block != null && nc.pod_ipv4_cidr_block != ""
    ]
  ))
}

# Get subnet details to retrieve the IP CIDR range
data "google_compute_subnetwork" "gke_subnet" {
  project = var.gke_project_id
  name    = local.subnet_name
  region  = local.cluster_region
}

module "castai_omni_cluster" {
  source  = "castai/omni-cluster/castai"
  version = "~> 2.5"

  k8s_provider    = "gke"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = module.castai_gke_cluster.organization_id
  cluster_id      = module.castai_gke_cluster.cluster_id
  cluster_name    = var.gke_cluster_name

  api_server_address    = "https://${data.google_container_cluster.gke.endpoint}"
  pod_cidrs             = local.pod_cidrs
  service_cidr          = data.google_container_cluster.gke.services_ipv4_cidr
  reserved_subnet_cidrs = [data.google_compute_subnetwork.gke_subnet.ip_cidr_range]

  skip_helm = var.skip_helm
}

module "castai_nebius_edge_location" {
  source = "../.."

  parent_id       = var.nebius_project_id
  cluster_id      = module.castai_gke_cluster.cluster_id
  organization_id = module.castai_gke_cluster.organization_id

  tags = {
    ManagedBy = "terraform"
  }

  depends_on = [module.castai_omni_cluster]
}
