#!/usr/bin/env bash
# Demo de Circuit Breaker + Retry + Timeout. Requiere: docker compose up --build (en otra terminal)
ORDERS=http://localhost:8080
PRICE=http://localhost:8081

set_mode() { curl -s -X POST "$PRICE/admin/mode/$1" > /dev/null; echo ">>> price-service en modo: $1"; }
order()    { curl -s -w "   (HTTP %{http_code}, %{time_total}s)\n" "$ORDERS/order"; }
title()    { echo; echo "=================== $1 ==================="; }

title "0. Modo OK: respuesta normal"
set_mode ok
order; order

title "1. RETRY: price-service falla 2 veces y luego responde (modo flaky)"
set_mode flaky
order
echo "(mira los logs: 3 intentos con esperas crecientes y respuesta final PRICE_SERVICE)"

title "2. TIMEOUT: price-service tarda 5 s, orders espera solo 2 s (modo slow)"
set_mode slow
order
echo "(respuesta FALLBACK en ~2 s, no en 5 s)"

title "3. CIRCUIT BREAKER: price-service caído (modo error)"
set_mode error
for i in 1 2 3 4 5 6; do echo "Petición $i:"; order; done
echo "Estado del circuito:"
curl -s "$ORDERS/actuator/circuitbreakers"; echo

title "4. RECUPERACIÓN: price-service vuelve a funcionar"
set_mode ok
echo "Esperando 11 s (tiempo en ABIERTO = 10 s)..."
sleep 11
for i in 1 2 3 4; do order; done
echo "Estado final del circuito:"
curl -s "$ORDERS/actuator/circuitbreakers"; echo
echo
echo "Ver transiciones en el log:  docker compose logs orders-service | grep '>>>'"
