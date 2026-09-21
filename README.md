# Taller de Reforzamiento – Sesión 2
## Docker, Azure Container Registry, Azure DevOps, VM y AKS

Repositorio de apoyo para estudiantes. Los archivos se entregan como **plantillas genéricas**: debes utilizar los nombres de los recursos que tú creaste en Azure y Azure DevOps.

## 1. Marcadores que debes reemplazar

| Marcador | Debes colocar |
|---|---|
| `<TU_SUSCRIPCION>` | Nombre o ID de tu suscripción de Azure |
| `<TU_RESOURCE_GROUP>` | Nombre de tu Resource Group |
| `<TU_VM>` | Nombre de tu Virtual Machine |
| `<TU_ACR>` | Nombre de tu Azure Container Registry, sin `.azurecr.io` |
| `<TU_AKS>` | Nombre de tu clúster AKS |
| `<TU_NAMESPACE>` | Namespace que utilizarás en Kubernetes |
| `<TU_SERVICE_CONNECTION_ACR>` | Nombre de tu Service Connection para ACR |
| `<TU_SERVICE_CONNECTION_ARM>` | Nombre de tu Service Connection de Azure Resource Manager, si corresponde |
| `<TU_PIPELINE_BUILD>` | Nombre exacto de tu pipeline Build/Push |
| `<TU_PIPELINE_DEPLOY_VM>` | Nombre de tu pipeline de deployment a VM |
| `<TU_ENVIRONMENT_VM>` | Nombre de tu Azure DevOps Environment con la VM registrada |
| `<TU_IMAGE_NAME>` | Nombre de tu imagen/repositorio Docker |

**No reemplaces un nombre correcto que ya utilizaste solo para copiar el ejemplo de otra persona.** Mantén consistencia entre Azure, Azure DevOps, GitHub, YAML, variables y evidencias.

## 2. Variables de Azure DevOps

Pipeline Build/Push:

```text
ACR_NAME=<TU_ACR>
IMAGE_NAME=<TU_IMAGE_NAME>
ACR_SERVICE_CONNECTION=<TU_SERVICE_CONNECTION_ACR>
```

Pipeline de deployment a VM:

```text
ACR_NAME=<TU_ACR>
IMAGE_NAME=<TU_IMAGE_NAME>
ACR_PULL_USERNAME=<CONFIGURAR_COMO_SECRET>
ACR_PULL_PASSWORD=<CONFIGURAR_COMO_SECRET>
```

No publiques contraseñas, tokens, access keys, secret keys ni otras credenciales en GitHub, YAML, README, capturas o logs.

## 3. Pipeline Build/Push

Archivo:

`azure-pipeline-push-image-acr.yml`

Este archivo ya utiliza variables para ACR, imagen y Service Connection. Crea tu pipeline con el nombre que definiste como `<TU_PIPELINE_BUILD>`.

## 4. Pipeline deployment a VM

Archivo:

`azure-pipelines-myappdocker-vm-acr.yml`

Antes de crear el pipeline debes reemplazar dentro del YAML:

```text
<TU_PIPELINE_BUILD>
<TU_ENVIRONMENT_VM>
```

Estos dos valores son estáticos porque Azure DevOps necesita resolver el pipeline de origen y el Environment al interpretar el YAML.

La VM no se escribe directamente en el YAML. Debe estar registrada dentro de `<TU_ENVIRONMENT_VM>`.

## 5. AKS: obtener las credenciales de tu clúster

```bash
az login
az account show --output table
az account set --subscription "<TU_SUSCRIPCION>"

az aks get-credentials \
  --resource-group <TU_RESOURCE_GROUP> \
  --name <TU_AKS> \
  --overwrite-existing

kubectl config current-context
kubectl get nodes -o wide
```

## 6. Kubernetes: desplegar en tu namespace

El manifiesto `aks-store-quickstart.yaml` es genérico y **no fija un namespace**.

Crear tu namespace:

```bash
kubectl create namespace <TU_NAMESPACE> \
  --dry-run=client -o yaml | kubectl apply -f -
```

Para el laboratorio se recomienda utilizar el script, porque prepara el Secret interno de RabbitMQ, aplica el manifiesto y valida la comunicación:

```bash
chmod +x scripts/deploy-aks.sh
./scripts/deploy-aks.sh <TU_NAMESPACE>
```

Si ya preparaste el Secret manualmente, puedes validar y aplicar el manifiesto directamente:

```bash
kubectl apply --dry-run=client -n <TU_NAMESPACE> -f aks-store-quickstart.yaml
kubectl apply -n <TU_NAMESPACE> -f aks-store-quickstart.yaml
```

Validar:

```bash
kubectl get pods -n <TU_NAMESPACE> -o wide
kubectl get svc -n <TU_NAMESPACE>
kubectl get endpoints -n <TU_NAMESPACE>
```

## 7. Azure Arc

Registrar los providers requeridos:

```bash
az extension add --name connectedk8s --upgrade
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation
```

Validar:

```bash
az provider show --namespace Microsoft.Kubernetes --query "registrationState" -o tsv
az provider show --namespace Microsoft.KubernetesConfiguration --query "registrationState" -o tsv
az provider show --namespace Microsoft.ExtendedLocation --query "registrationState" -o tsv
```

Conectar tu clúster:

```bash
az connectedk8s connect \
  --name <TU_AKS> \
  --resource-group <TU_RESOURCE_GROUP>
```

## 8. Service Account para la demostración

```bash
kubectl create serviceaccount demo-user -n <TU_NAMESPACE>

kubectl create clusterrolebinding demo-user-binding \
  --clusterrole cluster-admin \
  --serviceaccount <TU_NAMESPACE>:demo-user
```

Crear el Secret asociado:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-user-secret
  namespace: <TU_NAMESPACE>
  annotations:
    kubernetes.io/service-account.name: demo-user
type: kubernetes.io/service-account-token
EOF
```

Obtener el token:

```bash
TOKEN=$(kubectl get secret demo-user-secret \
  -n <TU_NAMESPACE> \
  -o jsonpath='{.data.token}' | base64 -d)

echo "$TOKEN"
```

No compartas ni incorpores el token en evidencias. Al finalizar:

```bash
unset TOKEN
```

> `cluster-admin` entrega privilegios administrativos sobre todo el clúster y se utiliza aquí solo para la demostración académica. En escenarios profesionales corresponde mínimo privilegio mediante RBAC.

## 9. Diagnóstico

```bash
kubectl get all -n <TU_NAMESPACE>
kubectl get events -n <TU_NAMESPACE> --sort-by=.lastTimestamp
```

Si aparece `CrashLoopBackOff`:

```bash
kubectl describe pod <TU_POD> -n <TU_NAMESPACE>
kubectl logs <TU_POD> -n <TU_NAMESPACE> --all-containers=true
kubectl logs <TU_POD> -n <TU_NAMESPACE> --all-containers=true --previous
```

La evidencia debe demostrar configuración, ejecución, comunicación, resultado y validación. **Lo que no se observa, no se puede asumir.**
