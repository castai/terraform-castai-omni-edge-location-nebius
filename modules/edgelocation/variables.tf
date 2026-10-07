variable "name" {
  type        = string
  description = "Name for the edge location. Use the same base name as the cloud resources (the cloud submodule's nebius_resources output includes it) so the edge location correlates with its cloud resources."
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

# =============================================================================
# Nebius cloud resources to reference (handoff bundle from the cloud submodule
# when the cloud resources and the edge location are owned by different
# parties; provided by the root module otherwise).
# =============================================================================

variable "parent_id" {
  description = "Nebius project ID that owns the edge location cloud resources."
  type        = string
}

variable "region" {
  description = "Nebius region for the edge location."
  type        = string
}

variable "service_account_id" {
  description = "Nebius service account impersonated by CAST AI (from the cloud resources handoff bundle)."
  type        = string
}

variable "network_id" {
  description = "VPC network for edge instances (from the cloud resources handoff bundle)."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for edge instances (from the cloud resources handoff bundle)."
  type        = string
}

variable "subnet_cidr" {
  description = "IPv4 CIDR of the subnet (from the cloud resources handoff bundle)."
  type        = string
}

variable "security_group_id" {
  description = "Security group for edge instances (from the cloud resources handoff bundle)."
  type        = string
}
