# Implementación técnica — plantilla para estudiantes

La guía principal se encuentra en [README.md](./README.md).

## Parámetros que debes conocer

```text
<TU_ACR>
<TU_IMAGE_NAME>
<TU_SERVICE_CONNECTION_ACR>
<TU_PIPELINE_BUILD>
<TU_PIPELINE_DEPLOY_VM>
<TU_ENVIRONMENT_VM>
<TU_VM>
```

## Pipeline 1 — Build, validación y Push

Archivo:

`azure-pipeline-push-image-acr.yml`

Configura en Azure DevOps:

```text
ACR_NAME=<TU_ACR>
IMAGE_NAME=<TU_IMAGE_NAME>
ACR_SERVICE_CONNECTION=<TU_SERVICE_CONNECTION_ACR>
```

El pipeline construye la imagen, valida `nginx -t`, levanta un contenedor temporal, verifica `/health` y `/api/info`, y solo después publica la imagen en ACR.

Crea este pipeline con el nombre que hayas definido como `<TU_PIPELINE_BUILD>`.

## Pipeline 2 — Deployment a VM

Archivo:

`azure-pipelines-myappdocker-vm-acr.yml`

Antes de crear el pipeline reemplaza dentro del archivo:

```text
<TU_PIPELINE_BUILD>
<TU_ENVIRONMENT_VM>
```

Luego configura:

```text
ACR_NAME=<TU_ACR>
IMAGE_NAME=<TU_IMAGE_NAME>
ACR_PULL_USERNAME=<SECRET>
ACR_PULL_PASSWORD=<SECRET>
```

La VM debe estar registrada dentro de `<TU_ENVIRONMENT_VM>`. El nombre `<TU_VM>` no necesita quedar escrito en el YAML.

El deployment utiliza el `runID` del pipeline de build para descargar exactamente la imagen correspondiente a esa ejecución, ejecuta Health Check y mantiene lógica de rollback.

## Seguridad

No almacenes en el repositorio:

- contraseñas;
- tokens;
- access keys o secret keys;
- credenciales ACR;
- claves privadas;
- archivos `.pem`;
- secretos de pipelines.

Marca las credenciales como Secret en Azure DevOps.

## Evidencia esperada

La evidencia debe permitir verificar:

1. variables configuradas sin exponer secretos;
2. Build y validaciones exitosas;
3. imagen publicada en ACR;
4. relación entre pipeline Build y pipeline Deploy;
5. VM registrada en el Environment correcto;
6. descarga de la imagen versionada;
7. contenedor en ejecución;
8. Health Check y `/api/info`;
9. corrección o diagnóstico frente a fallos.
