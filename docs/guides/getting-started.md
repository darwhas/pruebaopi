# Guía de Inicio Rápido - Plataforma DevOps

## 🚀 Introducción

Esta guía te ayudará a desplegar y configurar la plataforma DevOps completa en Azure AKS. La plataforma incluye:

- **Infraestructura como Código** con Terraform
- **GitOps** con ArgoCD
- **CI/CD** con Azure DevOps
- **Observabilidad** con Prometheus/Grafana
- **Seguridad** multicapa
- **Auto-scaling** y alta disponibilidad

## 📋 Prerrequisitos

### Herramientas Requeridas

```bash
# Azure CLI
az --version

# Terraform
terraform --version

# kubectl
kubectl version --client

# Helm
helm version

# PowerShell (Windows) o Bash (Linux/Mac)
```

### Cuentas y Permisos

- **Azure Subscription** con permisos de Owner/Contributor
- **Azure DevOps** Organization y Project
- **GitHub** o **Azure DevOps** para repositorios
- **Docker Hub** o **Azure Container Registry**

## 🏗️ Arquitectura de la Solución

### Componentes Principales

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Users     │  │   CDN       │  │   DNS       │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Cloud                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Application │  │   Key       │  │   ACR       │        │
│  │   Gateway   │  │   Vault     │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                              │                             │
│                              ▼                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              AKS Cluster                            │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │   NGINX     │  │   ArgoCD    │  │  Prometheus │ │   │
│  │  │  Ingress    │  │             │  │             │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  │                              │                     │   │
│  │                              ▼                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │Microservice │  │Microservice │  │Microservice │ │   │
│  │  │     1       │  │     2       │  │     N       │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Instalación y Configuración

### Paso 1: Clonar el Repositorio

```bash
git clone https://github.com/your-org/platform.git
cd platform
```

### Paso 2: Configurar Azure

```bash
# Login a Azure
az login

# Verificar suscripción
az account show

# Configurar suscripción (si tienes múltiples)
az account set --subscription "your-subscription-id"
```

### Paso 3: Configurar Variables de Entorno

```bash
# Crear archivo de configuración
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Editar configuración
nano terraform/environments/dev/terraform.tfvars
```

### Paso 4: Desplegar Infraestructura

```bash
# Usar script automatizado
./scripts/deploy-platform.ps1 -Environment dev -ResourceGroupName "platform-dev-rg"

# O manualmente
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Paso 5: Configurar GitOps

```bash
# Verificar ArgoCD
kubectl get pods -n argocd

# Obtener contraseña inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Acceder a ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Abrir https://localhost:8080
```

## 🔧 Configuración de Aplicaciones

### Crear un Nuevo Microservicio

1. **Crear estructura del proyecto**

```bash
mkdir my-microservice
cd my-microservice

# Estructura recomendada
my-microservice/
├── src/
│   ├── MyMicroservice/
│   │   ├── Controllers/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Program.cs
├── tests/
├── Dockerfile
├── .dockerignore
├── azure-pipelines.yml
└── README.md
```

2. **Configurar Dockerfile**

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["MyMicroservice.csproj", "./"]
RUN dotnet restore "MyMicroservice.csproj"
COPY . .
RUN dotnet build "MyMicroservice.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MyMicroservice.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyMicroservice.dll"]
```

3. **Configurar Helm Values**

```yaml
# values.yaml
application:
  name: "my-microservice"
  version: "1.0.0"
  environment: "development"
  domain: "platform.local"

image:
  repository: "platformacr.azurecr.io"
  tag: "latest"

ingress:
  enabled: true
  hosts:
    - host: "my-api.platform.local"
      paths:
        - path: /
          pathType: Prefix

env:
  application:
    - name: "DATABASE_CONNECTION"
      value: "mongodb://mongodb:27017"
    - name: "REDIS_CONNECTION"
      value: "redis://redis:6379"

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

4. **Configurar Pipeline CI/CD**

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop

variables:
  solution: '**/*.sln'
  buildPlatform: 'Any CPU'
  buildConfiguration: 'Release'
  dockerRegistryServiceConnection: 'platform-acr-service-connection'
  imageRepository: 'my-microservice'

stages:
- stage: Build
  jobs:
  - job: Build
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - task: UseDotNet@2
      inputs:
        version: '6.0.x'
    
    - task: DotNetCoreCLI@2
      inputs:
        command: 'build'
        projects: '$(solution)'
    
    - task: Docker@2
      inputs:
        containerRegistry: '$(dockerRegistryServiceConnection)'
        repository: '$(imageRepository)'
        command: 'buildAndPush'
        Dockerfile: '**/Dockerfile'
        tags: '$(Build.BuildNumber)'
```

## 📊 Monitoreo y Observabilidad

### Acceder a Grafana

```bash
# Port forward Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Abrir http://localhost:3000
# Usuario: admin
# Contraseña: prom-operator
```

### Dashboards Disponibles

- **Kubernetes Cluster Overview**
- **Application Metrics**
- **Infrastructure Monitoring**
- **Custom Application Dashboards**

### Configurar Alertas

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
spec:
  groups:
  - name: application.rules
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} errors per second"
```

## 🔒 Seguridad

### Configurar Network Policies

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservice-network-policy
  namespace: my-microservice
spec:
  podSelector:
    matchLabels:
      app: my-microservice
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 27017
```

### Configurar RBAC

```yaml
# rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-microservice
  name: microservice-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: microservice-role-binding
  namespace: my-microservice
subjects:
- kind: ServiceAccount
  name: my-microservice
  namespace: my-microservice
roleRef:
  kind: Role
  name: microservice-role
  apiGroup: rbac.authorization.k8s.io
```

## 🚀 Escalabilidad

### Configurar HPA (Horizontal Pod Autoscaler)

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-microservice-hpa
  namespace: my-microservice
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-microservice
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Configurar VPA (Vertical Pod Autoscaler)

```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-microservice-vpa
  namespace: my-microservice
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-microservice
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      minAllowed:
        cpu: 100m
        memory: 50Mi
      maxAllowed:
        cpu: 1
        memory: 500Mi
      controlledValues: RequestsAndLimits
```

## 🔄 GitOps Workflow

### Flujo de Trabajo

1. **Desarrollo**
   ```bash
   git checkout -b feature/new-feature
   # Hacer cambios
   git commit -m "Add new feature"
   git push origin feature/new-feature
   ```

2. **Pull Request**
   - Crear PR en Azure DevOps
   - Revisión de código
   - Tests automáticos
   - Aprobación

3. **Merge a Main**
   - Merge automático
   - Trigger CI pipeline
   - Build y push de imagen
   - Actualización de GitOps repo

4. **Despliegue Automático**
   - ArgoCD detecta cambios
   - Sincronización automática
   - Despliegue en AKS

### Rollback

```bash
# Rollback manual
kubectl rollout undo deployment/my-microservice -n my-microservice

# Rollback via ArgoCD
argocd app rollback my-microservice

# Rollback via GitOps
git revert HEAD
git push origin main
```

## 📈 Métricas y KPIs

### Métricas de Plataforma

- **Disponibilidad**: 99.9%
- **Time to Deploy**: < 10 minutos
- **Rollback Time**: < 2 minutos
- **MTTR**: < 30 minutos

### Métricas de Aplicación

- **Response Time**: < 200ms
- **Error Rate**: < 0.1%
- **Throughput**: > 1000 req/s
- **Resource Utilization**: < 80%

## 🛠️ Troubleshooting

### Problemas Comunes

1. **Pods no inician**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

2. **Problemas de red**
   ```bash
   kubectl get networkpolicies -n <namespace>
   kubectl describe networkpolicy <policy-name> -n <namespace>
   ```

3. **Problemas de recursos**
   ```bash
   kubectl top pods -n <namespace>
   kubectl describe node <node-name>
   ```

4. **Problemas de ArgoCD**
   ```bash
   kubectl get applications -n argocd
   kubectl describe application <app-name> -n argocd
   ```

### Logs y Debugging

```bash
# Ver logs de aplicación
kubectl logs -f deployment/my-microservice -n my-microservice

# Ver logs de ArgoCD
kubectl logs -f deployment/argocd-server -n argocd

# Ver logs de Prometheus
kubectl logs -f deployment/prometheus -n monitoring

# Debugging interactivo
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

## 📚 Recursos Adicionales

### Documentación

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Helm Documentation](https://helm.sh/docs/)

### Comunidad

- [Azure DevOps Community](https://dev.azure.com/community/)
- [Kubernetes Community](https://kubernetes.io/community/)
- [ArgoCD Community](https://argoproj.github.io/community/)

### Soporte

- **Issues**: Crear issue en el repositorio
- **Discussions**: Usar GitHub Discussions
- **Email**: devops@your-org.com

## 🎯 Próximos Pasos

1. **Configurar DNS** para tus dominios
2. **Implementar aplicaciones reales** usando los templates
3. **Configurar alertas** específicas para tu negocio
4. **Optimizar costos** con Spot Instances
5. **Implementar disaster recovery**
6. **Configurar compliance** y auditoría

