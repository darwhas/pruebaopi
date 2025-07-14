# Plataforma DevOps Integral - Azure AKS

## 📋 Descripción del Proyecto

Solución completa para una plataforma DevOps moderna en Azure AKS que soporta:
- **20+ microservicios .NET** y **4+ frontends Next.js**
- **Escalabilidad** para 20 microservicios adicionales y 3 frontends
- **Equipo DevOps pequeño** (máx. 3 personas)
- **GitOps** como mecanismo operativo central
- **Automatización completa** y **estandarización**

## 🏗️ Arquitectura

### Componentes Principales
- **AKS** - Azure Kubernetes Service
- **ACR** - Azure Container Registry
- **Application Gateway** - WAF y control de tráfico
- **Key Vault** - Gestión de secretos
- **ArgoCD** - GitOps
- **Prometheus/Grafana** - Observabilidad
- **MongoDB Atlas/Cosmos DB** - Base de datos
- **Azure Cache for Redis** - Caché

### Stack Tecnológico
- **IaC**: Terraform
- **GitOps**: ArgoCD
- **CI/CD**: Azure DevOps
- **Helm**: Charts reutilizables
- **Ingress**: NGINX + Application Gateway
- **Monitoring**: Prometheus + Grafana + Loki

## 📁 Estructura del Proyecto

```
├── 📁 terraform/                 # Infraestructura como Código
│   ├── 📁 modules/              # Módulos reutilizables
│   ├── 📁 environments/         # Configuraciones por ambiente
│   └── 📁 scripts/              # Scripts de automatización
├── 📁 helm-charts/              # Helm Charts reutilizables
│   ├── 📁 microservice-base/    # Chart base para microservicios
│   └── 📁 frontend-base/        # Chart base para frontends
├── 📁 pipelines/                # Pipelines CI/CD
│   ├── 📁 ci/                   # Pipeline de integración continua
│   └── 📁 cd/                   # Pipeline de despliegue continuo
├── 📁 gitops/                   # Configuración GitOps
│   ├── 📁 argocd/               # Configuración ArgoCD
│   └── 📁 applications/         # Manifiestos de aplicaciones
├── 📁 docs/                     # Documentación
│   ├── 📁 diagrams/             # Diagramas de arquitectura
│   └── 📁 guides/               # Guías de uso
└── 📁 scripts/                  # Scripts de utilidad
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Azure CLI
- Terraform >= 1.0
- kubectl
- Helm >= 3.0
- Docker

### Despliegue
1. **Configurar Azure**:
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Desplegar Infraestructura**:
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configurar GitOps**:
   ```bash
   kubectl apply -f gitops/argocd/
   ```

4. **Desplegar Aplicaciones**:
   ```bash
   kubectl apply -f gitops/applications/
   ```

## 📊 Métricas Esperadas

- **Time-to-market**: Reducción del 70% para nuevos microservicios
- **Rollbacks**: < 2 minutos para rollback completo
- **Disponibilidad**: 99.9% SLA
- **Escalabilidad**: Soporte para 40+ microservicios sin ampliar equipo

## 🔒 Seguridad

- **WAF** multicapa (Application Gateway + Cloudflare)
- **Secretos** centralizados en Key Vault
- **RBAC** granular en AKS
- **Network Policies** para aislamiento
- **Imágenes firmadas** y escaneadas

## 📈 Observabilidad

- **Métricas**: Prometheus + Grafana
- **Logs**: Loki + Grafana
- **Trazabilidad**: Distributed tracing
- **Alertas**: Integración con MS Teams/PagerDuty

## 🤝 Contribución

1. Fork del repositorio
2. Crear feature branch
3. Commit de cambios
4. Push al branch
5. Crear Pull Request

