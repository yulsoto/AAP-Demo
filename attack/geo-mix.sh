#!/usr/bin/env bash
#
# geo-mix.sh — genera ataques variados (SQLi, XSS, SSRF, scanner) desde IPs de
# varios paises (via X-Forwarded-For) para poblar:
#   - el geomap de AAP con multiples paises
#   - la serie de tiempo de "attack attempts by type" (SQLi / XSS / SSRF / scanner)
#
# Requiere DD_TRACE_CLIENT_IP_ENABLED=true en la app (ya esta en docker-compose),
# para que AAP use la IP del header en vez de la IP de egreso real.
#
# AAP inspecciona TODOS los parametros del request aunque la app no sea
# vulnerable a XSS/SSRF; por eso basta con mandar el payload en un parametro.
#
# Uso:  ./attack/geo-mix.sh http://localhost:8080 [vueltas]
#
set -uo pipefail

TARGET="${1:-http://localhost:8080}"
ROUNDS="${2:-3}"
UA="sqlmap/1.7 (http://sqlmap.org)"

B=$'\033[1m'; C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'

# IPs publicas reales que geolocalizan a paises distintos (pais | ip).
IPS=(
  "US|8.8.8.8"
  "China|114.114.114.114"
  "Rusia|77.88.8.8"
  "Alemania|213.133.98.98"
  "Brasil|200.221.11.100"
  "Mexico|200.57.7.61"
  "Francia|212.27.48.10"
  "Japon|126.33.44.55"
  "India|117.239.100.1"
  "Nigeria|41.58.120.33"
)

# Payloads por tipo de ataque (parametro | valor).
sqli() {  echo "q=' OR 1=1 --"; }
xss()  {  echo "q=<script>alert(document.cookie)</script>"; }
ssrf() {  echo "url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"; }

send() {  # pais ip descripcion param=valor [endpoint]
  local pais="$1" ip="$2" desc="$3" kv="$4" ep="${5:-/search}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -A "$UA" \
    -H "X-Forwarded-For: $ip" -G --data-urlencode "$kv" "$TARGET$ep")
  local color="$G"; [ "$code" = "403" ] && color="$R"
  printf "   %-9s %-18s %-10s ${color}HTTP %s${N}\n" "$pais" "$ip" "$desc" "$code"
}

echo "${B}== geo-mix: ataques desde varios paises -> $TARGET (${ROUNDS} vueltas) ==${N}"
echo "   (403 = bloqueado por la regla; 200 = detectado en modo monitor)"
echo

for r in $(seq 1 "$ROUNDS"); do
  echo "${B}-- vuelta $r --${N}"
  for entry in "${IPS[@]}"; do
    pais="${entry%%|*}"; ip="${entry##*|}"
    send "$pais" "$ip" "SQLi"    "$(sqli)"
    send "$pais" "$ip" "XSS"     "$(xss)"
    send "$pais" "$ip" "SSRF"    "$(ssrf)"
    send "$pais" "$ip" "CodeInj" "formula=dir(sys)" "/report"
    # un par de scans "limpios" para que tambien haya senal de scanner
    curl -s -o /dev/null -A "$UA" -H "X-Forwarded-For: $ip" \
      -G --data-urlencode "q=maria" "$TARGET/search"
    sleep 0.15
  done
  echo
done

echo "${G}Listo.${N} Revisa en Datadog:"
echo "  - AAP -> Signals: senales de SQLi, XSS y SSRF"
echo "  - El geomap debe mostrar US, China, Rusia, Alemania, Brasil, Mexico, Francia, Japon, India, Nigeria"
echo "  - La serie 'attack attempts by type' ya tiene XSS y SSRF ademas de SQLi"
