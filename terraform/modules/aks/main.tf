# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  
  # Network Profile
  network_profile {
    network_plugin     = "azure"
    network_policy     = var.enable_network_policies ? "azure" : null
    load_balancer_sku  = "standard"
    service_cidr       = "172.16.0.0/16"
    dns_service_ip     = "172.16.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }
  
  # Default Node Pool
  default_node_pool {
    name                = var.system_node_pool.name
    vm_size             = var.system_node_pool.vm_size
    os_disk_size_gb     = var.system_node_pool.os_disk_size_gb
    node_count          = var.system_node_pool.node_count
    max_pods            = var.system_node_pool.max_pods
    enable_auto_scaling = var.system_node_pool.enable_auto_scaling
    min_count           = var.system_node_pool.min_count
    max_count           = var.system_node_pool.max_count
    vnet_subnet_id      = var.vnet_subnet_id
    node_taints         = var.system_node_pool.node_taints
    type                = "VirtualMachineScaleSets"
  }
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # ACR Integration
  dynamic "acr_integration" {
    for_each = var.acr_id != null ? [1] : []
    content {
      acr_id = var.acr_id
    }
  }
  
  # Azure Monitor
  dynamic "addon_profile" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      oms_agent {
        enabled                    = true
        log_analytics_workspace_id = var.log_analytics_workspace_id
      }
    }
  }
  
  # Azure Policy
  dynamic "addon_profile" {
    for_each = var.enable_azure_policy ? [1] : []
    content {
      azure_policy {
        enabled = true
      }
    }
  }
  
  # Pod Security Policy
  dynamic "addon_profile" {
    for_each = var.enable_pod_security_policy ? [1] : []
    content {
      pod_security_policy {
        enabled = true
      }
    }
  }
  
  # Auto Scaling
  auto_scaler_profile {
    scale_down_delay_after_add = "15m"
    scale_down_unneeded        = "15m"
  }
  
  # Maintenance Window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3, 4, 5, 6]
    }
  }
  
  tags = var.tags
}

# User Node Pools
resource "azurerm_kubernetes_cluster_node_pool" "user_pools" {
  for_each = var.user_node_pools
  
  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  os_disk_size_gb       = each.value.os_disk_size_gb
  node_count            = each.value.node_count
  max_pods              = each.value.max_pods
  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  vnet_subnet_id        = var.vnet_subnet_id
  node_taints           = each.value.node_taints
  node_labels           = each.value.node_labels
  priority              = each.value.priority
  eviction_policy       = each.value.eviction_policy
  type                  = "VirtualMachineScaleSets"
  
  tags = merge(var.tags, {
    "node-pool" = each.key
  })
}

# Role Assignment for AKS to access ACR
resource "azurerm_role_assignment" "aks_acr" {
  count = var.acr_id != null ? 1 : 0
  
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Role Assignment for AKS to access Key Vault
resource "azurerm_role_assignment" "aks_key_vault" {
  count = var.key_vault_id != null ? 1 : 0
  
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
  
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }
  
  set {
    name  = "controller.resources.limits.cpu"
    value = "200m"
  }
  
  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Install Cert-Manager for SSL certificates
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
  
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Install Prometheus Operator
resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
  
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }
  
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Install ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
  
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  
  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.${var.domain_name}"
  }
  
  set {
    name  = "server.ingress.tls[0].secretName"
    value = "argocd-tls"
  }
  
  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "argocd.${var.domain_name}"
  }
  
  depends_on = [helm_release.nginx_ingress, helm_release.cert_manager]
} 