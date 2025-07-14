#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de despliegue completo de la plataforma DevOps en Azure AKS

.DESCRIPTION
    Este script automatiza el despliegue completo de la plataforma DevOps incluyendo:
    - Infraestructura como código (Terraform)
    - Configuración de AKS
    - Instalación de ArgoCD
    - Configuración de GitOps
    - Despliegue de aplicaciones de ejemplo

.PARAMETER Environment
    Ambiente a desplegar (dev, staging, production)

.PARAMETER ResourceGroupName
    Nombre del grupo de recursos

.PARAMETER Location
    Región de Azure

.PARAMETER SkipInfrastructure
    Omitir el despliegue de infraestructura

.PARAMETER SkipGitOps
    Omitir la configuración de GitOps

.EXAMPLE
    .\deploy-platform.ps1 -Environment production -ResourceGroupName "platform-rg" -Location "East US"

.NOTES
    Requiere: Azure CLI, Terraform, kubectl, Helm
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "platform-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipGitOps,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Configuración de colores para output
$Host.UI.RawUI.ForegroundColor = "White"
$Host.UI.RawUI.BackgroundColor = "Black"

# Función para logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Función para verificar prerequisitos
function Test-Prerequisites {
    Write-Log "Verificando prerequisitos..." "INFO"
    
    $prerequisites = @(
        @{ Name = "Azure CLI"; Command = "az" },
        @{ Name = "Terraform"; Command = "terraform" },
        @{ Name = "kubectl"; Command = "kubectl" },
        @{ Name = "Helm"; Command = "helm" }
    )
    
    foreach ($prereq in $prerequisites) {
        try {
            $null = Get-Command $prereq.Command -ErrorAction Stop
            Write-Log "✓ $($prereq.Name) encontrado" "SUCCESS"
        }
        catch {
            Write-Log "✗ $($prereq.Name) no encontrado. Por favor instálalo." "ERROR"
            exit 1
        }
    }
}

# Función para verificar login de Azure
function Test-AzureLogin {
    Write-Log "Verificando login de Azure..." "INFO"
    
    try {
        $context = az account show --query "name" -o tsv 2>$null
        if ($context) {
            Write-Log "✓ Conectado a Azure: $context" "SUCCESS"
        } else {
            throw "No hay sesión activa"
        }
    }
    catch {
        Write-Log "✗ No hay sesión activa de Azure. Ejecutando login..." "WARN"
        az login
    }
}

# Función para desplegar infraestructura
function Deploy-Infrastructure {
    Write-Log "Desplegando infraestructura con Terraform..." "INFO"
    
    $terraformDir = "terraform/environments/$Environment"
    
    if (-not (Test-Path $terraformDir)) {
        Write-Log "✗ Directorio de Terraform no encontrado: $terraformDir" "ERROR"
        exit 1
    }
    
    Push-Location $terraformDir
    
    try {
        # Inicializar Terraform
        Write-Log "Inicializando Terraform..." "INFO"
        terraform init
        
        # Plan de Terraform
        Write-Log "Generando plan de Terraform..." "INFO"
        terraform plan -out=tfplan
        
        if (-not $Force) {
            $confirmation = Read-Host "¿Deseas aplicar el plan? (y/N)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Log "Despliegue cancelado por el usuario" "WARN"
                return
            }
        }
        
        # Aplicar Terraform
        Write-Log "Aplicando configuración de Terraform..." "INFO"
        terraform apply tfplan
        
        # Obtener outputs
        $aksName = terraform output -raw aks_cluster_name
        $resourceGroup = terraform output -raw resource_group_name
        
        Write-Log "✓ Infraestructura desplegada exitosamente" "SUCCESS"
        Write-Log "AKS Cluster: $aksName" "INFO"
        Write-Log "Resource Group: $resourceGroup" "INFO"
        
        # Configurar kubectl
        Write-Log "Configurando kubectl..." "INFO"
        az aks get-credentials --resource-group $resourceGroup --name $aksName --overwrite-existing
        
        return @{
            AKSName = $aksName
            ResourceGroup = $resourceGroup
        }
    }
    catch {
        Write-Log "✗ Error desplegando infraestructura: $_" "ERROR"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Función para instalar ArgoCD
function Install-ArgoCD {
    Write-Log "Instalando ArgoCD..." "INFO"
    
    try {
        # Crear namespace si no existe
        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
        
        # Instalar ArgoCD
        kubectl apply -f gitops/argocd/argocd-install.yaml
        
        # Esperar a que ArgoCD esté listo
        Write-Log "Esperando a que ArgoCD esté listo..." "INFO"
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
        
        # Obtener contraseña inicial
        $argocdPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
        Write-Log "✓ ArgoCD instalado exitosamente" "SUCCESS"
        Write-Log "Contraseña inicial de ArgoCD: $argocdPassword" "INFO"
        
        return $argocdPassword
    }
    catch {
        Write-Log "✗ Error instalando ArgoCD: $_" "ERROR"
        exit 1
    }
}

# Función para configurar GitOps
function Setup-GitOps {
    param(
        [string]$ArgoCDPassword
    )
    
    Write-Log "Configurando GitOps..." "INFO"
    
    try {
        # Configurar repositorio de configuración
        $configRepo = "https://dev.azure.com/your-org/platform-config/_git/platform-config"
        
        # Crear aplicación de ejemplo
        $appManifest = @"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-config
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $configRepo
    targetRevision: main
    path: applications
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
"@
        
        $appManifest | kubectl apply -f -
        
        Write-Log "✓ GitOps configurado exitosamente" "SUCCESS"
    }
    catch {
        Write-Log "✗ Error configurando GitOps: $_" "ERROR"
        exit 1
    }
}

# Función para desplegar aplicaciones de ejemplo
function Deploy-SampleApplications {
    Write-Log "Desplegando aplicaciones de ejemplo..." "INFO"
    
    try {
        # Crear namespace para aplicaciones
        kubectl create namespace sample-apps --dry-run=client -o yaml | kubectl apply -f -
        
        # Desplegar microservicio de ejemplo
        $microserviceValues = @"
application:
  name: "sample-microservice"
  version: "1.0.0"
  environment: "$Environment"
  domain: "platform.local"

image:
  repository: "platformacr.azurecr.io"
  tag: "latest"

ingress:
  enabled: true
  hosts:
    - host: "sample-api.platform.local"
      paths:
        - path: /
          pathType: Prefix
"@
        
        $microserviceValues | Out-File -FilePath "sample-microservice-values.yaml" -Encoding UTF8
        
        # Usar sintaxis correcta de PowerShell para comandos multilínea
        helm install sample-microservice helm-charts/microservice-base `
            --namespace sample-apps `
            --values sample-microservice-values.yaml `
            --wait
        
        Write-Log "✓ Aplicaciones de ejemplo desplegadas" "SUCCESS"
    }
    catch {
        Write-Log "✗ Error desplegando aplicaciones de ejemplo: $_" "ERROR"
        exit 1
    }
}

# Función para verificar el despliegue
function Test-Deployment {
    Write-Log "Verificando despliegue..." "INFO"
    
    try {
        # Verificar pods
        $pods = kubectl get pods --all-namespaces --field-selector=status.phase!=Running
        if ($pods) {
            Write-Log "⚠️ Algunos pods no están ejecutándose:" "WARN"
            $pods | ForEach-Object { Write-Log "  $_" "WARN" }
        } else {
            Write-Log "✓ Todos los pods están ejecutándose" "SUCCESS"
        }
        
        # Verificar servicios
        $services = kubectl get services --all-namespaces
        Write-Log "Servicios desplegados:" "INFO"
        $services | ForEach-Object { Write-Log "  $_" "INFO" }
        
        # Verificar ArgoCD
        $argocdStatus = kubectl get application -n argocd
        Write-Log "Estado de aplicaciones ArgoCD:" "INFO"
        $argocdStatus | ForEach-Object { Write-Log "  $_" "INFO" }
        
        Write-Log "✓ Verificación completada" "SUCCESS"
    }
    catch {
        Write-Log "✗ Error verificando despliegue: $_" "ERROR"
    }
}

# Función para mostrar información final
function Show-FinalInfo {
    param(
        [hashtable]$InfrastructureInfo,
        [string]$ArgoCDPassword
    )
    
    Write-Log "=== DESPLIEGUE COMPLETADO ===" "SUCCESS"
    Write-Log ""
    Write-Log "🔗 URLs importantes:" "INFO"
    Write-Log "  - ArgoCD: https://argocd.platform.local" "INFO"
    Write-Log "  - Grafana: https://grafana.platform.local" "INFO"
    Write-Log "  - Sample API: https://sample-api.platform.local" "INFO"
    Write-Log ""
    Write-Log "🔑 Credenciales:" "INFO"
    Write-Log "  - ArgoCD Admin Password: $ArgoCDPassword" "INFO"
    Write-Log ""
    Write-Log "📊 Recursos desplegados:" "INFO"
    Write-Log "  - AKS Cluster: $($InfrastructureInfo.AKSName)" "INFO"
    Write-Log "  - Resource Group: $($InfrastructureInfo.ResourceGroup)" "INFO"
    Write-Log ""
    Write-Log "🚀 Próximos pasos:" "INFO"
    Write-Log "  1. Configurar DNS para apuntar a la IP del Application Gateway" "INFO"
    Write-Log "  2. Configurar certificados SSL con Cert-Manager" "INFO"
    Write-Log "  3. Desplegar aplicaciones reales usando GitOps" "INFO"
    Write-Log "  4. Configurar alertas y monitoreo" "INFO"
}

# Función principal
function Main {
    Write-Log "🚀 Iniciando despliegue de la plataforma DevOps" "INFO"
    Write-Log "Ambiente: $Environment" "INFO"
    Write-Log "Resource Group: $ResourceGroupName" "INFO"
    Write-Log "Location: $Location" "INFO"
    Write-Log ""
    
    # Verificar prerequisitos
    Test-Prerequisites
    
    # Verificar login de Azure
    Test-AzureLogin
    
    $infrastructureInfo = $null
    $argocdPassword = $null
    
    # Desplegar infraestructura
    if (-not $SkipInfrastructure) {
        $infrastructureInfo = Deploy-Infrastructure
    }
    
    # Instalar ArgoCD
    $argocdPassword = Install-ArgoCD
    
    # Configurar GitOps
    if (-not $SkipGitOps) {
        Setup-GitOps -ArgoCDPassword $argocdPassword
    }
    
    # Desplegar aplicaciones de ejemplo
    Deploy-SampleApplications
    
    # Verificar despliegue
    Test-Deployment
    
    # Mostrar información final
    Show-FinalInfo -InfrastructureInfo $infrastructureInfo -ArgoCDPassword $argocdPassword
    
    Write-Log "🎉 ¡Despliegue completado exitosamente!" "SUCCESS"
}

# Ejecutar función principal
Main 