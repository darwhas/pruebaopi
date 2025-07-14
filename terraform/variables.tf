# General Configuration
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "platform-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "platform"
    ManagedBy   = "terraform"
  }
}

# Network Configuration
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "platform-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Address prefixes for subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",  # AKS
    "10.0.2.0/24",  # Application Gateway
    "10.0.3.0/24",  # Private Endpoints
    "10.0.4.0/24"   # Bastion
  ]
}

# ACR Configuration
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "platformacr"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Premium"
}

variable "acr_admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

# Key Vault Configuration
variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "platform-kv"
}

# Application Gateway Configuration
variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "platform-agw"
}

# AKS Configuration
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "platform-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.27.7"
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    name                = string
    vm_size             = string
    os_disk_size_gb     = number
    node_count          = number
    max_pods            = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    node_taints         = list(string)
  })
  default = {
    name                = "systempool"
    vm_size             = "Standard_D4s_v3"
    os_disk_size_gb     = 128
    node_count          = 3
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 5
    node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
  }
}

variable "user_node_pools" {
  description = "User node pools configuration"
  type = map(object({
    vm_size             = string
    os_disk_size_gb     = number
    node_count          = number
    max_pods            = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    priority            = string
    eviction_policy     = string
    node_taints         = list(string)
    node_labels         = map(string)
  }))
  default = {
    "cpu-optimized" = {
      vm_size             = "Standard_D8s_v3"
      os_disk_size_gb     = 128
      node_count          = 2
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 2
      max_count           = 10
      priority            = "Regular"
      eviction_policy     = "Delete"
      node_taints         = []
      node_labels = {
        "workload-type" = "cpu-intensive"
        "pool-type"     = "cpu-optimized"
      }
    },
    "memory-optimized" = {
      vm_size             = "Standard_E8s_v3"
      os_disk_size_gb     = 128
      node_count          = 2
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 2
      max_count           = 8
      priority            = "Regular"
      eviction_policy     = "Delete"
      node_taints         = []
      node_labels = {
        "workload-type" = "memory-intensive"
        "pool-type"     = "memory-optimized"
      }
    },
    "spot-pool" = {
      vm_size             = "Standard_D4s_v3"
      os_disk_size_gb     = 128
      node_count          = 1
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 5
      priority            = "Spot"
      eviction_policy     = "Delete"
      node_taints         = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
      node_labels = {
        "workload-type" = "batch"
        "pool-type"     = "spot"
      }
    }
  }
}

# Monitoring Configuration
variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "platform-logs"
}

# DNS Configuration
variable "dns_zone_name" {
  description = "DNS zone name for the platform"
  type        = string
  default     = "platform.local"
}

# Security Configuration
variable "enable_network_policies" {
  description = "Enable network policies on AKS"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Enable pod security policy on AKS"
  type        = bool
  default     = false
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy on AKS"
  type        = bool
  default     = true
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable backup for resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 30
} 