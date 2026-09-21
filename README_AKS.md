# Parte 2 — AKS Store Demo

Esta guía utiliza nombres genéricos para que cada estudiante trabaje con sus propios recursos.

## Parámetros

Antes de comenzar identifica:

```text
<TU_RESOURCE_GROUP> = tu Resource Group
<TU_AKS>            = tu clúster AKS
<TU_NAMESPACE>      = tu namespace Kubernetes
<TU_SUSCRIPCION>    = nombre o ID de tu suscripción
```

El manifiesto `aks-store-quickstart.yaml` no fija un namespace. El namespace se selecciona al momento de aplicar el archivo.

## Versiones utilizadas

- RabbitMQ: `rabbitmq:4.3.2-management-alpine`
- Order Service: `ghcr.io/azure-samples/aks-store-demo/order-service:2.2.0`
- Product Service: `ghcr.io/azure-samples/aks-store-demo/product-service:2.2.0`
- Store Front: `ghcr.io/azure-samples/aks-store-demo/store-front:2.2.0`
- BusyBox: `busybox:1.37.0`

Se fijan versiones para reducir cambios inesperados por tags `latest`.

## Obtener acceso al AKS

```bash
az login
az account set --subscription "<TU_SUSCRIPCION>"

az aks get-credentials \
  --resource-group <TU_RESOURCE_GROUP> \
  --name <TU_AKS> \
  --overwrite-existing

kubectl config current-context
kubectl get nodes -o wide
```

## Despliegue recomendado

El script recibe el namespace como parámetro:

```bash
chmod +x scripts/deploy-aks.sh
./scripts/deploy-aks.sh <TU_NAMESPACE>
```

El script:

1. valida `kubectl` y acceso al clúster;
2. crea el namespace si no existe;
3. crea o reutiliza el Secret `rabbitmq-auth`;
4. valida el manifiesto con `dry-run`;
5. aplica los recursos en `<TU_NAMESPACE>`;
6. espera los rollouts;
7. valida DNS y comunicación entre servicios;
8. muestra Pods, Services, endpoints y diagnóstico ante errores.

## Aplicación manual

Crear el namespace:

```bash
kubectl create namespace <TU_NAMESPACE> \
  --dry-run=client -o yaml | kubectl apply -f -
```

Crear el Secret sin almacenar la contraseña en archivos:

```bash
read -rp "RabbitMQ user: " RABBITMQ_USER
read -rsp "RabbitMQ password: " RABBITMQ_PASS
echo

kubectl create secret generic rabbitmq-auth \
  -n <TU_NAMESPACE> \
  --from-literal=username="$RABBITMQ_USER" \
  --from-literal=password="$RABBITMQ_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

unset RABBITMQ_USER RABBITMQ_PASS
```

Validar y aplicar:

```bash
kubectl apply --dry-run=client -n <TU_NAMESPACE> -f aks-store-quickstart.yaml
kubectl apply -n <TU_NAMESPACE> -f aks-store-quickstart.yaml
```

## Comunicación interna

Los Services se resuelven mediante DNS de Kubernetes dentro del mismo namespace:

```text
rabbitmq:5672
order-service:3000
product-service:3002
store-front:80
```

No utilices IP de Pods como dependencia permanente, porque pueden cambiar después de un reinicio.

## Validaciones

```bash
kubectl get pods -n <TU_NAMESPACE> -o wide
kubectl get svc -n <TU_NAMESPACE>
kubectl get endpoints -n <TU_NAMESPACE>

kubectl rollout status statefulset/rabbitmq -n <TU_NAMESPACE>
kubectl rollout status deployment/product-service -n <TU_NAMESPACE>
kubectl rollout status deployment/order-service -n <TU_NAMESPACE>
kubectl rollout status deployment/store-front -n <TU_NAMESPACE>
```

Eventos:

```bash
kubectl get events -n <TU_NAMESPACE> --sort-by=.lastTimestamp
```

Si aparece `CrashLoopBackOff`:

```bash
kubectl describe pod <TU_POD> -n <TU_NAMESPACE>
kubectl logs <TU_POD> -n <TU_NAMESPACE> --all-containers=true
kubectl logs <TU_POD> -n <TU_NAMESPACE> --all-containers=true --previous
```

## Azure Arc

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

Conectar:

```bash
az connectedk8s connect \
  --name <TU_AKS> \
  --resource-group <TU_RESOURCE_GROUP>
```

## Service Account para demostración

```bash
kubectl create serviceaccount demo-user -n <TU_NAMESPACE>

kubectl create clusterrolebinding demo-user-binding \
  --clusterrole cluster-admin \
  --serviceaccount <TU_NAMESPACE>:demo-user
```

Secret:

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

Token:

```bash
TOKEN=$(kubectl get secret demo-user-secret \
  -n <TU_NAMESPACE> \
  -o jsonpath='{.data.token}' | base64 -d)

echo "$TOKEN"
unset TOKEN
```

No incluyas el token en GitHub, capturas o logs compartidos.

> El uso de `cluster-admin` corresponde únicamente a esta demostración académica. En escenarios profesionales aplica mínimo privilegio.

## Exposición pública

```bash
kubectl get svc store-front -n <TU_NAMESPACE> -w
```

Cuando `EXTERNAL-IP` deje de mostrar `<pending>`, valida la aplicación desde esa dirección.

## Limpieza

```bash
kubectl delete namespace <TU_NAMESPACE>
```

Esto elimina los recursos de la aplicación creados dentro de tu namespace.
