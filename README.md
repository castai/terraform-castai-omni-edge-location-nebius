# terraform-castai-omni-edge-location-nebius

Terraform module for creating CAST AI edge locations on Nebius AI Cloud.

> **Status: draft**
>
> This module assumes the CAST AI terraform provider exposes a `nebius` block on
> `castai_edge_location` and `castai_edge_configuration`, analogous to the
> existing `aws` / `gcp` / `oci` blocks. That support is not yet available in
> the published `castai/castai` provider; the module is a draft that will be
> refined once Nebius support lands in the provider.

## Usage

> **Warning**
> This module expects the cluster to be onboarded to CAST AI with OMNI enabled.

### Prerequisites

The Nebius terraform provider authenticates as a Nebius service account using
an authorized key. Configure the provider out-of-band (e.g. via environment
variables or a profile), and ensure the calling identity has `editor` or
`admin` rights in the target project so it can create service accounts,
authorized keys, VPC networks, subnets, and security groups.

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

  tags = {
    ManagedBy = "terraform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_castai"></a> [castai](#requirement\_castai) | >= 8.46.0 |
| <a name="requirement_nebius"></a> [nebius](#requirement\_nebius) | >= 0.6.8 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [castai_edge_configuration.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/edge_configuration) | resource |
| [castai_edge_configuration_default.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/edge_configuration_default) | resource |
| [castai_edge_location.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/edge_location) | resource |
| [nebius_iam_v1_auth_public_key.castai](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/iam_v1_auth_public_key) | resource |
| [nebius_iam_v1_group_membership.castai](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/iam_v1_group_membership) | resource |
| [nebius_iam_v1_service_account.castai](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/iam_v1_service_account) | resource |
| [nebius_vpc_v1_network.main](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/vpc_v1_network) | resource |
| [nebius_vpc_v1_security_group.main](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/vpc_v1_security_group) | resource |
| [nebius_vpc_v1_security_rule.egress_all](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/vpc_v1_security_rule) | resource |
| [nebius_vpc_v1_security_rule.ingress_self](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/vpc_v1_security_rule) | resource |
| [nebius_vpc_v1_subnet.main](https://registry.terraform.io/providers/nebius/nebius/latest/docs/resources/vpc_v1_subnet) | resource |
| [null_resource.validate](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [tls_private_key.castai_authorized_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [castai_omni_cluster.this](https://registry.terraform.io/providers/castai/castai/latest/docs/data-sources/omni_cluster) | data source |
| [nebius_iam_v2_project.this](https://registry.terraform.io/providers/nebius/nebius/latest/docs/data-sources/iam_v2_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | Optional addons to install on the edge cluster. Defaults to null (provider installs nvidia-gpu-operator by default).<br/>Set to an empty list to install no addons.<br/><br/>Each addon supports:<br/>- name (string, required): Addon identifier. One of: nvidia-gpu-operator, nvidia-dra, nvidia-network-operator, oci-csi.<br/>- values (string, optional): Helm values for the addon, encoded as a JSON object. | <pre>list(object({<br/>    name   = string<br/>    values = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | CAST AI cluster ID | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Edge location control plane configuration.<br/>- ha (bool): enable high availability mode for the Edge location control plane (default: true) | <pre>object({<br/>    ha = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_default_edge_configuration_name"></a> [default\_edge\_configuration\_name](#input\_default\_edge\_configuration\_name) | Name of the default edge configuration | `string` | `""` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the edge location | `string` | `null` | no |
| <a name="input_edge_configurations"></a> [edge\_configurations](#input\_edge\_configurations) | Map of Nebius edge configurations to create for this edge location.<br/><br/>Each configuration supports the following attributes:<br/>- name (string, required): Name of the edge configuration.<br/>- image\_id (string, optional): Nebius image ID for edge instances (e.g. an image OCID or family name).<br/>- boot\_disk\_size\_gib (number, optional): Boot disk size in GiB.<br/>- user\_data\_base64 (string, optional): Base64 encoded user data to run on the edge as part of bootstrap. The payload must start with either `#cloud-config` (cloud-init YAML) or `#!` (shell script with a shebang).<br/>- labels (map(string), optional): Labels to apply to edge instances created with this configuration.<br/>- cri (map(string), optional): Container runtime interface configuration. Defaults to `{}`.<br/><br/>Example:<br/>edge\_configurations = {<br/>  "default" = {<br/>    image\_id = "ubuntu-22.04-lts"<br/>    labels = {<br/>      environment = "production"<br/>    }<br/>  }<br/>  "gpu" = {<br/>    image\_id           = "ubuntu-22.04-lts-cuda"<br/>    boot\_disk\_size\_gib = 200<br/>    labels = {<br/>      workload = "gpu"<br/>    }<br/>  }<br/>} | <pre>map(object({<br/>    name               = string<br/>    image_id           = optional(string)<br/>    boot_disk_size_gib = optional(number)<br/>    user_data_base64   = optional(string)<br/>    cri                = optional(map(string), {})<br/>    labels             = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_editors_group_id"></a> [editors\_group\_id](#input\_editors\_group\_id) | ID of the Nebius IAM group (e.g. the default `editors` group in the project)<br/>that the CAST AI service account will be added to so it can manage compute<br/>and network resources. If not provided, the service account is created but<br/>not added to any group; you must grant permissions out-of-band. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the edge location. If not provided, will be auto-generated | `string` | `null` | no |
| <a name="input_networking"></a> [networking](#input\_networking) | Edge cluster networking configuration.<br/>- tunneled\_cidrs (list(string)): list of destination CIDR blocks whose traffic should be routed through the main cluster instead of directly from the edge cluster. | <pre>object({<br/>    tunneled_cidrs = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | CAST AI organization ID | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | Nebius project ID that will own the edge location resources (VPC network,<br/>subnet, security group, service account). Must match the parent project<br/>configured in the Nebius provider.<br/><br/>Nebius projects are created per region, so the project's region is read<br/>automatically from the project and used for the edge location. A separate<br/>`region` input is therefore not required. | `string` | n/a | yes |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | CIDR block for the Nebius subnet private IPv4 pool | `string` | `"10.0.0.0/24"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Labels to apply to Nebius resources (Nebius calls these `labels`) | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the Nebius VPC network private IPv4 pool | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_edge_configuration_ids"></a> [edge\_configuration\_ids](#output\_edge\_configuration\_ids) | Map of edge configuration IDs by configuration key |
| <a name="output_edge_location_id"></a> [edge\_location\_id](#output\_edge\_location\_id) | CAST AI edge location ID |
| <a name="output_edge_location_name"></a> [edge\_location\_name](#output\_edge\_location\_name) | CAST AI edge location name |
| <a name="output_nebius_resources"></a> [nebius\_resources](#output\_nebius\_resources) | Nebius resources created for the edge location |
<!-- END_TF_DOCS -->

## License

MIT
