# Lab AAP — ProsperIA (Escenario 1: ataque en vivo de punta a punta)

Lab de demo para **Datadog App & API Protection (AAP)**. Monta una app
deliberadamente vulnerable (Flask + Postgres) instrumentada con el tracer de
Datadog, y un script que lanza un ataque **en vivo** para que Jennifer vea la
traza completa: **quién ataca → con qué payload → cómo se clasificó → cómo se
bloqueó → qué remediación se sugiere.** Nada estático.

> ⚠️ Solo para demo. La app tiene una SQLi a propósito. No la expongas en
> producción ni la uses contra sistemas que no sean tuyos.

## Componentes

| Pieza | Qué hace |
|---|---|
| `app/app.py` | API de pacientes. `/search?q=` tiene SQLi vía f-string (línea marcada); `/login` expuesto a credential stuffing. |
| `docker-compose.yml` | App + Postgres + Datadog Agent. AAP, IAST y Remote Config habilitados. |
| `attack/attacker.sh` | Genera el ataque en vivo: scanner UA → payloads SQLi → credential stuffing. |
| `terraform/` | Levanta todo en una EC2 con IP pública (para que geo/reputación se vean reales). |

## Opción A — Local (rápido, para ensayar)

```bash
cp .env.example .env     # pon tu DD_API_KEY
docker compose up -d --build
./attack/attacker.sh http://localhost:8080
```

Local la IP del atacante será privada; para que se vea geo/reputación real en la
demo, usa Terraform.

### Demo en vivo, paso por paso

Para presentar: `attack/demo.sh` va pausando entre cada paso para que te cambies
a Datadog y lo muestres, e imprime el guion de "qué decir".

```bash
./attack/demo.sh http://localhost:8080      # o la IP de la EC2
```

Nota: si tu org ya tiene la regla OWASP de SQLi en modo *Block* (Remote Config),
el SQLi devolverá `403` desde el paso 2. El contraste "antes/después" en vivo se
luce mejor con **Block IP** en el paso 5: el escaneo benigno (`q=maria`) pasa de
`200` a `403` una vez bloqueada la IP.

## Opción B — Terraform (recomendado para la demo)

```bash
cd terraform
cat > terraform.tfvars <<'EOF'
key_name   = "mi-keypair"
dd_api_key = "xxxxx"
repo_url   = "https://github.com/yulsoto/AAP-Demo.git"
allowed_cidrs = ["TU.IP.PUBLICA/32"]
EOF
terraform init && terraform apply
```

`terraform output` te da la `app_url` y el `attack_command` listo.

## Flujo en la demo (~10 min)

| # | Pantalla | Qué decir |
|---|---|---|
| 1 | Correr `attacker.sh` en vivo con pantalla compartida | "Esto lo está haciendo alguien afuera, ahorita." |
| 2 | **AAP → Signals:** aparece la señal SQLi/Scanner | Así se clasificó: severidad y regla OWASP |
| 3 | **Attacker / IP:** geo, reputación, # de requests | Así se ve quién está afuera |
| 4 | **Trace → pestaña Security:** parámetro `q` con el payload exacto y la regla que hizo match | Los datos de entrada en tiempo real: "el auto en movimiento" |
| 5 | **Traza completa:** request → Flask → query a Postgres | Muestra si el ataque llegó a la base o no |
| 6 | **Block IP** (Remote Config, con duración) → correr otra vez → 403 y traza marcada como *blocked* | Así responde la cerradura |
| 7 | **Señal de ATO** (credential stuffing) → bloquear al usuario o las IPs | Gancho hacia el session hijacking |
| 8 | **Next steps / Bits AI / Case** → remediación + vulnerabilidad IAST en la línea exacta del f-string | Qué te sugiero para remediar |

## Exploit Prevention (RASP)

El lab trae RASP habilitado (`DD_APPSEC_RASP_ENABLED=true`). RASP engancha el
sink de Postgres (psycopg2) y detecta el SQLi **en el momento en que llegaría a
la base**, con stack trace de la línea exacta.

- **Detección:** sale de fábrica en modo *monitor* → verás el evento de
  *Exploit Prevention* en la pestaña **Security** de la traza, con el stack trace.
- **Bloqueo (403):** se activa por Remote Config desde la UI, sin redeploy:
  **Security → App and API Protection → Protection → Exploit Prevention** → ponlo
  en **Block**. Luego corre `attacker.sh` otra vez y el SQLi devuelve `403`.

> Requiere `ddtrace>=2.21`. La versión del lab ya cumple.

## Dónde mirar en Datadog

- **Signals:** Security → App and API Protection → Signals (`service:prosperia-patient-api`)
- **Traces:** APM → Traces, filtra `@appsec.security_activity:*`
- **Block IP:** en la señal o el trace → *Block IP*, elige duración → corre `attacker.sh` de nuevo → 403
- **IAST (paso 8):** Security → Code Security → el hallazgo de SQL injection apunta a la línea del `f"SELECT ..."` en `app.py`

## Checklist pre-demo

- [ ] `DD_API_KEY` de la org de demo cargada
- [ ] Corrí `attacker.sh` una vez y confirmé que la señal aparece
- [ ] Probé el Block IP y el 403 en vivo
- [ ] Plan B: screenshots / grabación del flujo por si falla la red
