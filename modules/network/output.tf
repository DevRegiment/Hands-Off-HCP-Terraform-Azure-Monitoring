output "vnet_id" {
  value = azurerm_virtual_network.this.id
}


output "subnet_id" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}
