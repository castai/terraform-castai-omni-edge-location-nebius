variable "name" {
  type        = string
  description = "Name for the edge location. If not provided, will be auto-generated"
  default     = null

  validation {
    # Nebius resource names are limited to 63 chars. The name is prefixed with
    # "castai-omni-" (12 chars) and the longest suffix is "-ingress-self"
    # (13 chars), so the sanitized name must be at most 38 chars. replace()
    # maps each character 1:1, so the sanitized length equals the raw length.
    condition = var.name == null || length(lower(replace(var.name, "/[^a-zA-Z0-9-]/", "-"))) <= 63 - 12 - 13

    error_message = "name must be at most 38 characters after sanitization so that prefixed and suffixed resource names fit within Nebius' 63-character limit."
  }
}

variable "api_url" {
  type        = string
  description = "CAST AI API URL"
  default     = null
}

variable "api_token" {
  type        = string
  description = "CAST AI API token"
  sensitive   = true
  default     = null
}

variable "cluster_id" {
  type        = string
  description = "CAST AI cluster ID"
}

variable "organization_id" {
  type        = string
  description = "CAST AI organization ID"
}

variable "description" {
  type        = string
  description = "Description of the edge location"
  default     = null
}

variable "parent_id" {
  description = <<-EOT
    Nebius project ID that owns the edge location resources (VPC network,
    subnet, security group, service account). When provisioning the cloud
    resources, it must match the parent project configured in the Nebius
    provider. It is also passed to the castai_edge_location nebius block in
    all modes, so it is required even when provision_cloud is
    false.

    Nebius projects are created per region, so var.region must match the
    project's region; it is validated against the project when the cloud
    resources are provisioned.
  EOT
  type        = string
}

variable "region" {
  type        = string
  description = "Region of the parent Nebius project (must match the project's actual region)."
}

variable "provision_cloud" {
  description = <<-EOT
    Whether to provision the Nebius cloud resources (service account, WIF
    federated credentials, editors group, VPC network/subnet and security
    group) in the Nebius project (var.parent_id).

    Set to false to reference cloud resources provisioned separately (the
    owner of the edge location, when cloud resources and edge location are
    owned by different parties) via var.existing_nebius_resources and
    var.region instead; no Nebius credentials are needed in that mode.
  EOT
  type        = bool
  default     = true
}

variable "provision_edgelocation" {
  description = <<-EOT
    Whether to provision the CAST AI edge location and its edge
    configurations (castai_edge_location, castai_edge_configuration and the
    default edge configuration).

    Set to false to provision only the Nebius cloud resources (the owner of
    the cloud resources, when cloud resources and edge location are owned by
    different parties); combined with var.castai_oidc_subject_id, no CAST AI
    data is read in that mode. Note that the castai provider is still
    configured (Terraform configures providers for all resources in the
    configuration, even with count = 0) and requires a valid API token, e.g.
    via the CASTAI_API_TOKEN environment variable.
  EOT
  type        = bool
  default     = true

  validation {
    condition     = var.provision_cloud || var.provision_edgelocation
    error_message = "At least one of provision_cloud and provision_edgelocation must be true."
  }
}

variable "castai_oidc_subject_id" {
  description = <<-EOT
    CAST AI GCP service account unique ID of the Omni cluster, used as the
    federated subject of the Nebius WIF credential. It is read from the
    castai_omni_cluster data source
    (castai_oidc_config.gcp_service_account_unique_id) by the owner of the
    edge location (or of the cluster) and provided to the owner of the
    cloud resources when the two are separate.

    When not set, the module reads it from the castai_omni_cluster data
    source, which requires CAST AI API credentials. Set it explicitly to
    avoid that data source read in cloud-only mode (the castai provider
    still needs to be configured with a valid API token, e.g. via the
    CASTAI_API_TOKEN environment variable).
  EOT
  type        = string
  default     = null
}

variable "existing_nebius_resources" {
  description = <<-EOT
    Handoff bundle of existing Nebius cloud resources to reference when
    provision_cloud is false. This is the nebius_resources output of the
    run that provisioned the cloud resources.

    Fields:
    - service_account_id (string, required): Nebius service account impersonated by CAST AI.
    - network_id (string, required): VPC network for edge instances.
    - subnet_id (string, required): Subnet for edge instances.
    - subnet_cidr (string, required): IPv4 CIDR of the subnet.
    - security_group_id (string, required): Security group for edge instances.
  EOT
  type = object({
    service_account_id = string
    network_id         = string
    subnet_id          = string
    subnet_cidr        = string
    security_group_id  = string
  })
  default = null

  validation {
    condition     = var.provision_cloud || var.existing_nebius_resources != null
    error_message = "existing_nebius_resources must be set when provision_cloud is false (the handoff bundle from the run that provisioned the cloud resources)."
  }

  validation {
    condition     = !var.provision_cloud || var.existing_nebius_resources == null
    error_message = "existing_nebius_resources must not be set when provision_cloud is true; the module provisions the resources itself."
  }
}

variable "editors_group_id" {
  description = <<-EOT
    ID of the Nebius IAM group (e.g. the default `editors` group in the project)
    that the CAST AI service account will be added to so it can manage compute
    and network resources. If not provided, a dedicated IAM group is created
    automatically and granted the `editor` role on the project, so no
    out-of-band permission setup is required.
  EOT
  type        = string
  default     = null
}

variable "network_cidr" {
  description = "CIDR block for the Nebius network address pool. Defines the network's private IPv4 address space."
  type        = string
  default     = "10.0.0.0/13"
}

variable "subnet_cidr" {
  description = "CIDR block for the Nebius subnet. Must be within the network CIDR (var.network_cidr)."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    # Check both mask specificity and address containment: the subnet mask
    # must be >= the network mask (smaller block), and masking the subnet's
    # network address with the network's prefix must yield the network's own
    # address.
    condition     = tonumber(split("/", var.subnet_cidr)[1]) >= tonumber(split("/", var.network_cidr)[1]) && cidrhost(format("%s/%s", cidrhost(var.subnet_cidr, 0), split("/", var.network_cidr)[1]), 0) == cidrhost(var.network_cidr, 0)
    error_message = "subnet_cidr must be within the network_cidr address range."
  }
}

variable "tags" {
  description = "Labels to apply to Nebius resources (Nebius calls these `labels`)"
  type        = map(string)
  default     = {}
}

variable "control_plane" {
  description = <<-EOT
    Edge location control plane configuration.
    - ha (bool): enable high availability mode for the Edge location control plane (default: true)
    - external_address (string, optional): the IP address or hostname used to reach the API server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).
    - api_server_port (number, optional): the port used for the API server. Defaults to the system value when unset.
    - konnectivity_port (number, optional): the port used for the konnectivity server. Defaults to the system value when unset.
    - service_annotations (map(string), optional): custom annotations to apply to the control plane service.
  EOT
  type = object({
    ha                  = optional(bool, true)
    external_address    = optional(string)
    api_server_port     = optional(number)
    konnectivity_port   = optional(number)
    service_annotations = optional(map(string))
  })
  default = {}
}

variable "liqo" {
  description = <<-EOT
    Liqo configuration for the edge cluster.
    - gateway_replicas (number, optional): number of active replicas for the Liqo gateway servers and clients. Defaults to 1 when unset.
    - gateway_server (object, optional): configuration overrides for the Liqo gateway server:
      - service_labels (map(string), optional): custom labels to apply to the Liqo gateway service.
      - service_annotations (map(string), optional): custom annotations to apply to the Liqo gateway service.
      - external_address (string, optional): the IP address or hostname used to reach the Liqo gateway server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).
      - external_port (number, optional): the port used for the Liqo gateway server. Defaults to the system value when unset.
  EOT
  type = object({
    gateway_replicas = optional(number)
    gateway_server = optional(object({
      service_labels      = optional(map(string))
      service_annotations = optional(map(string))
      external_address    = optional(string)
      external_port       = optional(number)
    }))
  })
  default = null
}

variable "networking" {
  description = <<-EOT
    Edge cluster networking configuration.
    - tunneled_cidrs (list(string)): list of destination CIDR blocks whose traffic should be routed through the main cluster instead of directly from the edge cluster.
  EOT
  type = object({
    tunneled_cidrs = optional(list(string))
  })
  default = null
}

variable "edge_configurations" {
  description = <<-EOT
    Map of Nebius edge configurations to create for this edge location.

    Each configuration supports the following attributes:
    - name (string, required): Name of the edge configuration.
    - image_id (string, optional): Nebius image ID for edge instances (e.g. an image OCID or family name).
    - boot_disk_size_gib (number, optional): Boot disk size in GiB.
    - user_data_base64 (string, optional): Base64 encoded user data to run on the edge as part of bootstrap. The payload must start with either `#cloud-config` (cloud-init YAML) or `#!` (shell script with a shebang).
    - labels (map(string), optional): Labels to apply to edge instances created with this configuration.
    - cri (map(string), optional): Container runtime interface configuration. Defaults to `{}`.
    - reservation_ids (list(string), optional): Capacity block reservation IDs.
    - gpu_cluster (string, optional): GPU cluster info.

    Example:
    edge_configurations = {
      "default" = {
        image_id = "ubuntu-22.04-lts"
        labels = {
          environment = "production"
        }
      }
      "gpu" = {
        image_id           = "ubuntu-22.04-lts-cuda"
        boot_disk_size_gib = 200
        labels = {
          workload = "gpu"
        }
        
        reservation_ids = ["res-1", "res-2"]
        gpu_cluster     = "cluster-1"
      }
    }
  EOT
  type = map(object({
    name               = string
    image_id           = optional(string)
    boot_disk_size_gib = optional(number)
    user_data_base64   = optional(string)
    cri                = optional(map(string), {})
    labels             = optional(map(string), {})
    reservation_ids    = optional(list(string))
    gpu_cluster        = optional(string)
  }))
  default = {}
}

variable "addons" {
  description = <<-EOT
    Optional addons to install on the edge cluster. Defaults to null (provider installs nvidia-gpu-operator by default).
    Set to an empty list to install no addons.

    Each addon supports:
    - name (string, required): Addon identifier. One of: nvidia-gpu-operator, nvidia-dra, nvidia-network-operator, oci-csi.
    - values (string, optional): Helm values for the addon, encoded as a JSON object.
  EOT
  type = list(object({
    name   = string
    values = optional(string)
  }))
  default = null
}

variable "default_edge_configuration_name" {
  type        = string
  description = "Name of the default edge configuration"
  default     = ""

  validation {
    condition     = var.default_edge_configuration_name == "" || can(var.edge_configurations[var.default_edge_configuration_name])
    error_message = "The specified default_edge_configuration_name does not match any key in var.edge_configurations."
  }
}

variable "wait_for_location_ready" {
  type        = bool
  description = "Optional wait for location to be ready before finishing the module execution.  This option requires `api_url` and `api_token` to be set"
  default     = false

  validation {
    condition = !var.wait_for_location_ready || (var.api_url != null && var.api_token != null)

    error_message = "api_url and api_token must be set when wait_for_location_ready is true"
  }
}
