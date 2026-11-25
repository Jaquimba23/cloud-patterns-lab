#!/usr/bin/env bash
# Requiere: docker compose up -d  (en esta carpeta)
URL=http://localhost:8088

echo "=== 1. Balanceo round robin (6 peticiones) ==="
for i in 1 2 3 4 5 6; do echo -n "Petición $i: "; curl -s $URL; done

echo
echo "=== 2. Se detiene app1 (simula una falla) ==="
docker stop app1 > /dev/null
for i in 1 2 3 4; do echo -n "Petición $i: "; curl -s $URL; done

echo
echo "=== 3. Se vuelve a iniciar app1 ==="
docker start app1 > /dev/null
sleep 12
for i in 1 2 3 4; do echo -n "Petición $i: "; curl -s $URL; done
