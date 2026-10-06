# terraform-castai-omni-edge-location-nebius

Terraform module for creating CAST AI edge locations on Nebius AI Cloud.

> Authentication uses Nebius Workload Identity Federation (WIF): the module
> creates a Nebius service account and a `nebius_iam_v1_federated_credentials`
> resource that binds CAST AI's GCP OIDC identity to the service account. CAST AI
> impersonates the service account referenced by the nebius block's
> `service_account_id` via OIDC token exchange, so no static authorized-key
> credentials are ever passed to CAST AI.

## Usage

> **Warning**
> This module expects the cluster to be onboarded to CAST AI with OMNI enabled.

### Prerequisites

The Nebius terraform provider authenticates as a Nebius service account using
an authorized key. Configure the provider out-of-band (e.g. via environment
variables or a profile), and ensure the calling identity has `editor` or
`admin` rights in the target project so it can create service accounts,
federated credentials, VPC networks, subnets, and security groups.

```hcl
provider "nebius" {
  service_account = {
    account_id_env       = "SA_ID"
    public_key_id_env    = "AUTHKEY_PUBLIC_ID"
    private_key_file_env = "AUTHKEY_PRIVATE_PATH"
  }
}

module "castai_nebius_edge_location" {
  source  = "castai/omni-edge-location-nebius/castai"
  version = "~> 0.1"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  parent_id = var.nebius_project_id
  region    = var.region

  tags = {
    ManagedBy = "terraform"
  }
}
```

## Split ownership

The module is composed of two submodules, each ownable by a different party:

1. **Cloud resources** (`modules/cloud`): service account, WIF federated
   credentials, editors group, VPC network/subnet, security group. Requires
   only Nebius credentials.
2. **Edge location** (`modules/edgelocation`): `castai_edge_location` and
   edge configurations. Requires only CAST AI credentials.

The root module composes both for full mode (a single run, both credential
sets). When the two parts are owned by different parties, each party calls
its submodule directly. The owner of the edge location may also use the raw
`castai_edge_location` resource instead of the submodule.

### Handoff sequence (split ownership)

```text
1. The cluster is onboarded to CAST AI with OMNI enabled
   (prerequisite for any edge location).

2. Edge location owner -> cloud resources owner:
   gcp_service_account_unique_id, read from the castai_omni_cluster data
   source (castai_oidc_config). One string.

3. Cloud resources owner runs modules/cloud with it as
   castai_oidc_subject_id -> creates the Nebius service account, WIF
   credential, VPC, security group.

4. Cloud resources owner -> edge location owner: the nebius_resources output
   (the handoff bundle: parent_id, region, service_account_id, network_id,
   subnet_id, subnet_cidr, security_group_id).

5. Edge location owner runs modules/edgelocation with the handoff bundle
   -> creates the CAST AI edge location and edge configurations.
```

### Cloud resources only (owner of the cloud resources)

```hcl
module "castai_nebius_edge_cloud" {
  source = "castai/omni-edge-location-nebius/castai//modules/cloud"

  name      = "my-edge-location"
  parent_id = var.nebius_project_id
  region    = var.region

  cluster_id = var.cluster_id

  # WIF federated subject, provided by the edge location owner
  # (see handoff step 2).
  castai_oidc_subject_id = var.castai_oidc_subject_id
}

# The nebius_resources output is the handoff bundle for the owner of the
# edge location (it includes the name, so both runs can correlate their
# resources).
output "nebius_resources" {
  value = module.castai_nebius_edge_cloud.nebius_resources
}
```

### Edge location only (owner of the edge location)

```hcl
module "castai_nebius_edge_location" {
  source = "castai/omni-edge-location-nebius/castai//modules/edgelocation"

  name            = "my-edge-location" # from the handoff bundle
  organization_id = var.organization_id
  cluster_id      = var.cluster_id

  # Handoff bundle from the cloud-resources run (its nebius_resources output).
  parent_id          = var.nebius_parent_id
  region             = var.region
  service_account_id = var.nebius_service_account_id
  network_id         = var.nebius_network_id
  subnet_id          = var.nebius_subnet_id
  subnet_cidr        = var.nebius_subnet_cidr
  security_group_id  = var.nebius_security_group_id
}
```

See `examples/cloud-only` and `examples/edge-location-only` for complete,
runnable versions of the split usage.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_castai"></a> [castai](#requirement\_castai) | >= 9.6.3 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |
| <a name="requirement_nebius"></a> [nebius](#requirement\_nebius) | >= 0.6.8 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloud"></a> [cloud](#module\_cloud) | ./modules/cloud | n/a |
| <a name="module_edgelocation"></a> [edgelocation](#module\_edgelocation) | ./modules/edgelocation | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.validate](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [castai_omni_cluster.this](https://registry.terraform.io/providers/castai/castai/latest/docs/data-sources/omni_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | Optional addons to install on the edge cluster. Defaults to null (provider installs nvidia-gpu-operator by default).<br/>Set to an empty list to install no addons.<br/><br/>Each addon supports:<br/>- name (string, required): Addon identifier. One of: nvidia-gpu-operator, nvidia-dra, nvidia-network-operator, oci-csi.<br/>- values (string, optional): Helm values for the addon, encoded as a JSON object. | <pre>list(object({<br/>    name   = string<br/>    values = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | CAST AI API token | `string` | `null` | no |
| <a name="input_api_url"></a> [api\_url](#input\_api\_url) | CAST AI API URL | `string` | `null` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | CAST AI cluster ID | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Edge location control plane configuration.<br/>- ha (bool): enable high availability mode for the Edge location control plane (default: true)<br/>- external\_address (string, optional): the IP address or hostname used to reach the API server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).<br/>- api\_server\_port (number, optional): the port used for the API server. Defaults to the system value when unset.<br/>- konnectivity\_port (number, optional): the port used for the konnectivity server. Defaults to the system value when unset.<br/>- service\_annotations (map(string), optional): custom annotations to apply to the control plane service. | <pre>object({<br/>    ha                  = optional(bool, true)<br/>    external_address    = optional(string)<br/>    api_server_port     = optional(number)<br/>    konnectivity_port   = optional(number)<br/>    service_annotations = optional(map(string))<br/>  })</pre> | `{}` | no |
| <a name="input_default_edge_configuration_name"></a> [default\_edge\_configuration\_name](#input\_default\_edge\_configuration\_name) | Name of the default edge configuration | `string` | `""` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the edge location | `string` | `null` | no |
| <a name="input_edge_configurations"></a> [edge\_configurations](#input\_edge\_configurations) | Map of Nebius edge configurations to create for this edge location.<br/><br/>Each configuration supports the following attributes:<br/>- name (string, required): Name of the edge configuration.<br/>- image\_id (string, optional): Nebius image ID for edge instances (e.g. an image OCID or family name).<br/>- boot\_disk\_size\_gib (number, optional): Boot disk size in GiB.<br/>- user\_data\_base64 (string, optional): Base64 encoded user data to run on the edge as part of bootstrap. The payload must start with either `#cloud-config` (cloud-init YAML) or `#!` (shell script with a shebang).<br/>- labels (map(string), optional): Labels to apply to edge instances created with this configuration.<br/>- cri (map(string), optional): Container runtime interface configuration. Defaults to `{}`.<br/>- reservation\_ids (list(string), optional): Capacity block reservation IDs.<br/>- gpu\_cluster (string, optional): GPU cluster info.<br/><br/>Example:<br/>edge\_configurations = {<br/>  "default" = {<br/>    image\_id = "ubuntu-22.04-lts"<br/>    labels = {<br/>      environment = "production"<br/>    }<br/>  }<br/>  "gpu" = {<br/>    image\_id           = "ubuntu-22.04-lts-cuda"<br/>    boot\_disk\_size\_gib = 200<br/>    labels = {<br/>      workload = "gpu"<br/>    }<br/>    <br/>    reservation\_ids = ["res-1", "res-2"]<br/>    gpu\_cluster     = "cluster-1"<br/>  }<br/>} | <pre>map(object({<br/>    name               = string<br/>    image_id           = optional(string)<br/>    boot_disk_size_gib = optional(number)<br/>    user_data_base64   = optional(string)<br/>    cri                = optional(map(string), {})<br/>    labels             = optional(map(string), {})<br/>    reservation_ids    = optional(list(string))<br/>    gpu_cluster        = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_editors_group_id"></a> [editors\_group\_id](#input\_editors\_group\_id) | ID of the Nebius IAM group (e.g. the default `editors` group in the project)<br/>that the CAST AI service account will be added to so it can manage compute<br/>and network resources. If not provided, a dedicated IAM group is created<br/>automatically and granted the `editor` role on the project, so no<br/>out-of-band permission setup is required. | `string` | `null` | no |
| <a name="input_liqo"></a> [liqo](#input\_liqo) | Liqo configuration for the edge cluster.<br/>- gateway\_replicas (number, optional): number of active replicas for the Liqo gateway servers and clients. Defaults to 1 when unset.<br/>- gateway\_server (object, optional): configuration overrides for the Liqo gateway server:<br/>  - service\_labels (map(string), optional): custom labels to apply to the Liqo gateway service.<br/>  - service\_annotations (map(string), optional): custom annotations to apply to the Liqo gateway service.<br/>  - external\_address (string, optional): the IP address or hostname used to reach the Liqo gateway server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).<br/>  - external\_port (number, optional): the port used for the Liqo gateway server. Defaults to the system value when unset. | <pre>object({<br/>    gateway_replicas = optional(number)<br/>    gateway_server = optional(object({<br/>      service_labels      = optional(map(string))<br/>      service_annotations = optional(map(string))<br/>      external_address    = optional(string)<br/>      external_port       = optional(number)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the edge location. If not provided, will be auto-generated | `string` | `null` | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | CIDR block for the Nebius network address pool. Defines the network's private IPv4 address space. | `string` | `"10.0.0.0/13"` | no |
| <a name="input_networking"></a> [networking](#input\_networking) | Edge cluster networking configuration.<br/>- tunneled\_cidrs (list(string)): list of destination CIDR blocks whose traffic should be routed through the main cluster instead of directly from the edge cluster. | <pre>object({<br/>    tunneled_cidrs = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | CAST AI organization ID | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | Nebius project ID that will own the edge location resources (VPC network,<br/>subnet, security group, service account). Must match the parent project<br/>configured in the Nebius provider.<br/><br/>Nebius projects are created per region, so var.region must match the<br/>project's region; it is validated against the project when the cloud<br/>resources are provisioned. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the parent Nebius project (must match the project's actual region). | `string` | n/a | yes |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | CIDR block for the Nebius subnet. Must be within the network CIDR (var.network\_cidr). | `string` | `"10.0.0.0/24"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Labels to apply to Nebius resources (Nebius calls these `labels`) | `map(string)` | `{}` | no |
| <a name="input_wait_for_location_ready"></a> [wait\_for\_location\_ready](#input\_wait\_for\_location\_ready) | Optional wait for location to be ready before finishing the module execution.  This option requires `api_url` and `api_token` to be set | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_debug_gcp_sa_email"></a> [debug\_gcp\_sa\_email](#output\_debug\_gcp\_sa\_email) | n/a |
| <a name="output_debug_gcp_sa_unique_id"></a> [debug\_gcp\_sa\_unique\_id](#output\_debug\_gcp\_sa\_unique\_id) | n/a |
| <a name="output_edge_configuration_ids"></a> [edge\_configuration\_ids](#output\_edge\_configuration\_ids) | Map of edge configuration IDs by configuration key |
| <a name="output_edge_location_id"></a> [edge\_location\_id](#output\_edge\_location\_id) | CAST AI edge location ID |
| <a name="output_edge_location_name"></a> [edge\_location\_name](#output\_edge\_location\_name) | CAST AI edge location name |
| <a name="output_nebius_federated_credentials_id"></a> [nebius\_federated\_credentials\_id](#output\_nebius\_federated\_credentials\_id) | ID of the Nebius WIF federated credentials binding CAST AI's GCP OIDC identity to the service account |
| <a name="output_nebius_resources"></a> [nebius\_resources](#output\_nebius\_resources) | Nebius resources created for the edge location, including everything needed to configure a castai\_edge\_location (nebius block) directly |
<!-- END_TF_DOCS -->

## License

MIT
