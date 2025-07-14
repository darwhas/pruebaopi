output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "app_gateway_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

output "private_endpoints_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "public_ip_id" {
  description = "ID of the Application Gateway public IP"
  value       = azurerm_public_ip.app_gateway.id
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "bastion_host_id" {
  description = "ID of the Bastion host"
  value       = azurerm_bastion_host.main.id
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = azurerm_public_ip.bastion.ip_address
} 