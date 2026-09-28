# Modules

## network

A VNet with any number of subnets. Each subnet gets its own NSG and the association between them.

### Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `resource_group_name` | `string` | required | Resource group to deploy into |
| `location` | `string` | `"uksouth"` | Azure region |
| `vnet_name` | `string` | required | Virtual network name |
| `address_space` | `list(string)` | required | VNet address space |
| `subnets` | `map(string)` | required | Subnet name → CIDR |
| `tags` | `map(string)` | see `variables.tf` | Tags for the VNet and NSGs |

### Outputs

| Name | Description |
|---|---|
| `vnet_id` | Virtual network ID |
| `subnet_id` | Map of subnet name → subnet ID |

### Usage

```hcl
module "network" {
  source              = "../modules/network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  vnet_name           = "vnet-example"
  address_space       = ["10.40.0.0/16"]
  subnets = {
    snet-app = "10.40.1.0/24"
  }
  tags = azurerm_resource_group.example.tags
}

# module.network.subnet_id["snet-app"]
```

Used by the `hands-off-hcp` config in this repo.
