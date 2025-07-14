terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate${random_string.storage_account.result}"
    container_name       = "tfstate"
    key                  = "platform.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Random string for unique naming
resource "random_string" "storage_account" {
  length  = 8
  special = false
  upper   = false
}

# Data sources
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Resource Group
resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Network
module "network" {
  source = "./modules/network"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  vnet_name          = var.vnet_name
  address_space      = var.vnet_address_space
  subnet_prefixes    = var.subnet_prefixes
  tags              = var.tags
}

# Container Registry
module "acr" {
  source = "./modules/acr"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  acr_name           = var.acr_name
  sku                = var.acr_sku
  admin_enabled      = var.acr_admin_enabled
  tags              = var.tags
}

# Key Vault
module "key_vault" {
  source = "./modules/key_vault"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  key_vault_name     = var.key_vault_name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  tags              = var.tags
}

# Application Gateway
module "app_gateway" {
  source = "./modules/app_gateway"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  gateway_name       = var.app_gateway_name
  subnet_id          = module.network.app_gateway_subnet_id
  public_ip_id       = module.network.public_ip_id
  tags              = var.tags
}

# AKS Cluster
module "aks" {
  source = "./modules/aks"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  cluster_name       = var.aks_cluster_name
  kubernetes_version = var.kubernetes_version
  
  # Node Pools
  system_node_pool = var.system_node_pool
  user_node_pools  = var.user_node_pools
  
  # Network
  vnet_subnet_id = module.network.aks_subnet_id
  
  # ACR Integration
  acr_id = module.acr.id
  
  # Monitoring
  log_analytics_workspace_id = module.monitoring.workspace_id
  
  tags = var.tags
}

# Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  resource_group_name = azurerm_resource_group.platform.name
  location           = azurerm_resource_group.platform.location
  workspace_name     = var.log_analytics_workspace_name
  tags              = var.tags
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "app_gateway_public_ip" {
  value = module.network.public_ip_address
} 