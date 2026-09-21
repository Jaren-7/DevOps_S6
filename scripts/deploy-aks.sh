#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${1:-${NAMESPACE:-}}"
MANIFEST="aks-store-quickstart.yaml"
SECRET_NAME="rabbitmq-auth"
NETWORK_CHECK_POD="network-check"

if [[ -z "$NAMESPACE" ]]; then
  echo "Uso: ./scripts/deploy-aks.sh <TU_NAMESPACE>"
  echo "Ejemplo conceptual: ./scripts/deploy-aks.sh nombre-de-tu-namespace"
  echo "Alternativa: NAMESPACE=<TU_NAMESPACE> ./scripts/deploy-aks.sh"
  exit 2
fi

log() {
  printf '\n==> %s\n' "$1"
}

diagnostics() {
  echo
  echo "========== DIAGNÓSTICO AKS =========="
  kubectl get pods -n "$NAMESPACE" -o wide || true
  echo
  kubectl get svc -n "$NAMESPACE" || true
  echo
  kubectl get endpoints -n "$NAMESPACE" || true
  echo
  kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 40 || true
  echo

  while read -r pod; do
    [[ -z "$pod" ]] && continue
    echo "----- describe $pod -----"
    kubectl describe pod "$pod" -n "$NAMESPACE" || true
    echo "----- logs actuales $pod -----"
    kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true --tail=120 || true
    echo "----- logs previos $pod -----"
    kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true --previous --tail=120 || true
  done < <(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

  echo "====================================="
}

trap 'echo "ERROR: el despliegue o una validación falló."; diagnostics' ERR

log "Validando herramientas"
command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl no está instalado. Instálalo o usa Azure Cloud Shell."
  exit 1
}

command -v openssl >/dev/null 2>&1 || {
  echo "openssl no está instalado y se requiere para generar la credencial temporal de RabbitMQ."
  exit 1
}

[[ -f "$MANIFEST" ]] || {
  echo "No se encontró $MANIFEST en el directorio actual."
  exit 1
}

kubectl version --client
kubectl cluster-info >/dev/null

log "Validando manifiesto antes de aplicar"
kubectl apply --dry-run=client -n "$NAMESPACE" -f "$MANIFEST" >/dev/null
echo "Manifiesto válido."

log "Preparando namespace y secreto interno"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "El secreto $SECRET_NAME ya existe. Se reutilizará sin mostrar su contenido."
else
  RABBITMQ_USER="rabbitmquser"
  RABBITMQ_PASSWORD="$(openssl rand -hex 24)"

  kubectl create secret generic "$SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-literal=username="$RABBITMQ_USER" \
    --from-literal=password="$RABBITMQ_PASSWORD" >/dev/null

  unset RABBITMQ_PASSWORD
  echo "Secreto $SECRET_NAME creado correctamente."
fi

log "Aplicando recursos"
kubectl apply -n "$NAMESPACE" -f "$MANIFEST"

log "Esperando RabbitMQ"
kubectl rollout status statefulset/rabbitmq -n "$NAMESPACE" --timeout=5m

log "Esperando product-service"
kubectl rollout status deployment/product-service -n "$NAMESPACE" --timeout=5m

log "Esperando order-service"
kubectl rollout status deployment/order-service -n "$NAMESPACE" --timeout=5m

log "Esperando store-front"
kubectl rollout status deployment/store-front -n "$NAMESPACE" --timeout=5m

log "Validando DNS y comunicación interna"
kubectl delete pod "$NETWORK_CHECK_POD" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

kubectl run "$NETWORK_CHECK_POD" \
  -n "$NAMESPACE" \
  --image=busybox:1.37.0 \
  --restart=Never \
  --command -- sh -c '
    set -e
    echo "DNS RabbitMQ:" && nslookup rabbitmq
    echo "AMQP RabbitMQ:" && nc -z -w 5 rabbitmq 5672
    echo "Health order-service:" && wget -qO- http://order-service:3000/health
    echo
    echo "Health product-service:" && wget -qO- http://product-service:3002/health
    echo
    echo "Health store-front:" && wget -qO- http://store-front/health
    echo
  '

kubectl wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/"$NETWORK_CHECK_POD" \
  -n "$NAMESPACE" \
  --timeout=90s

kubectl logs "$NETWORK_CHECK_POD" -n "$NAMESPACE"
kubectl delete pod "$NETWORK_CHECK_POD" -n "$NAMESPACE" --ignore-not-found

log "Estado final"
kubectl get pods -n "$NAMESPACE" -o wide
kubectl get svc -n "$NAMESPACE"

echo
EXTERNAL_IP="$(kubectl get svc store-front -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
EXTERNAL_HOST="$(kubectl get svc store-front -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ -n "$EXTERNAL_IP" ]]; then
  echo "Store Front: http://$EXTERNAL_IP"
elif [[ -n "$EXTERNAL_HOST" ]]; then
  echo "Store Front: http://$EXTERNAL_HOST"
else
  echo "El LoadBalancer todavía no tiene IP/DNS público."
  echo "Monitorea con: kubectl get svc store-front -n $NAMESPACE -w"
fi

echo
echo "Despliegue y comunicación interna validados correctamente."
