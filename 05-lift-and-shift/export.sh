#!/usr/bin/env bash
# Empaqueta la aplicación y su configuración desde el servidor "on-premise" (contenedor).
# Requiere: docker compose up -d --build  (en esta carpeta)
set -e
rm -rf export migration-package.tar.gz
mkdir -p export/srv export/etc/nginx/conf.d

docker cp onprem-server:/srv/app export/srv/app
docker cp onprem-server:/etc/nginx/conf.d/app.conf export/etc/nginx/conf.d/app.conf

tar -czf migration-package.tar.gz -C export srv etc

echo
echo "=== Paquete de migracion creado ==="
ls -lh migration-package.tar.gz
echo
echo "=== SHA256 en ORIGEN (on-premise) ==="
sha256sum export/srv/app/clientes.csv
