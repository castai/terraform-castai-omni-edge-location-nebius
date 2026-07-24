variable "name" {
  type        = string
  description = "Name for the edge location. If not provided, will be auto-generated"
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
    Nebius project ID that will own the edge location resources (VPC network,
    subnet, security group, service account). Must match the parent project
    configured in the Nebius provider.

    Nebius projects are created per region, so the project's region is read
    automatically from the project and used for the edge location. A separate
    `region` input is therefore not required.
  EOT
  type        = string
}

variable "editors_group_id" {
  description = <<-EOT
    ID of the Nebius IAM group (e.g. the default `editors` group in the project)
    that the CAST AI service account will be added to so it can manage compute
    and network resources. If not provided, the service account is created but
    not added to any group; you must grant permissions out-of-band.
  EOT
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the Nebius VPC network private IPv4 pool"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the Nebius subnet private IPv4 pool"
  type        = string
  default     = "10.0.0.0/24"
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
  EOT
  type = object({
    ha = optional(bool, true)
  })
  default = {}
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
