# Imagen base estable y liviana. Evitamos :latest para reducir cambios inesperados.
FROM nginx:stable-alpine

ARG BUILD_ID=local
ARG SOURCE_COMMIT=local

LABEL org.opencontainers.image.title="devops-nginx-app" \
      org.opencontainers.image.description="Nginx de demostración para pipeline DevOps" \
      org.opencontainers.image.version="${BUILD_ID}" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}"

# Reemplaza la configuración por la definida en el repositorio.
COPY default.conf /etc/nginx/conf.d/default.conf

# Copia el contenido web.
COPY html/ /usr/share/nginx/html/

# Inyecta metadatos del build para que sean visibles en la página.
RUN sed -i "s|__BUILD_ID__|${BUILD_ID}|g; s|__SOURCE_COMMIT__|${SOURCE_COMMIT}|g" \
      /usr/share/nginx/html/index.html \
    && nginx -t

EXPOSE 80

# Permite validar automáticamente que Nginx realmente responde.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1
