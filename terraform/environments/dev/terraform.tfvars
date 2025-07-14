# Development Environment Configuration
# This file contains the specific configuration for the development environment

# General Configuration
resource_group_name = "platform-dev-rg"
location           = "East US"
environment        = "development"

# Tags
tags = {
  Environment = "development"
  Project     = "platform"
  ManagedBy   = "terraform"
  Owner       = "devops-team"
  CostCenter  = "platform-dev"
}

# Network Configuration
vnet_name          = "platform-dev-vnet"
vnet_address_space = ["10.1.0.0/16"]
subnet_prefixes    = [
  "10.1.1.0/24",  # AKS
  "10.1.2.0/24",  # Application Gateway
  "10.1.3.0/24",  # Private Endpoints
  "10.1.4.0/24"   # Bastion
]

# ACR Configuration
acr_name           = "platformdevacr"
acr_sku            = "Standard"
acr_admin_enabled  = true

# Key Vault Configuration
key_vault_name     = "platform-dev-kv"

# Application Gateway Configuration
app_gateway_name   = "platform-dev-agw"

# AKS Configuration
aks_cluster_name   = "platform-dev-aks"
kubernetes_version = "1.27.7"

# System Node Pool (Development - Smaller)
system_node_pool = {
  name                = "systempool"
  vm_size             = "Standard_D2s_v3"
  os_disk_size_gb     = 64
  node_count          = 2
  max_pods            = 110
  enable_auto_scaling = true
  min_count           = 2
  max_count           = 3
  node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
}

# User Node Pools (Development - Smaller)
user_node_pools = {
  "cpu-optimized" = {
    vm_size             = "Standard_D4s_v3"
    os_disk_size_gb     = 64
    node_count          = 1
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
    priority            = "Regular"
    eviction_policy     = "Delete"
    node_taints         = []
    node_labels = {
      "workload-type" = "cpu-intensive"
      "pool-type"     = "cpu-optimized"
      "environment"   = "development"
    }
  },
  "memory-optimized" = {
    vm_size             = "Standard_E4s_v3"
    os_disk_size_gb     = 64
    node_count          = 1
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
    priority            = "Regular"
    eviction_policy     = "Delete"
    node_taints         = []
    node_labels = {
      "workload-type" = "memory-intensive"
      "pool-type"     = "memory-optimized"
      "environment"   = "development"
    }
  },
  "spot-pool" = {
    vm_size             = "Standard_D2s_v3"
    os_disk_size_gb     = 64
    node_count          = 1
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
    priority            = "Spot"
    eviction_policy     = "Delete"
    node_taints         = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
    node_labels = {
      "workload-type" = "batch"
      "pool-type"     = "spot"
      "environment"   = "development"
    }
  }
}

# Monitoring Configuration
log_analytics_workspace_name = "platform-dev-logs"

# DNS Configuration
dns_zone_name = "dev.platform.local"

# Security Configuration
enable_network_policies     = true
enable_pod_security_policy  = false
enable_azure_policy         = true

# Backup Configuration
enable_backup         = true
backup_retention_days = 7 