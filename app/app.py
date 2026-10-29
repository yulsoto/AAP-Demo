"""
Lab AAP ProsperIA — app deliberadamente vulnerable para demo de Datadog App & API Protection.

NO USAR EN PRODUCCION. Contiene una SQL injection a proposito (parametro `q`)
y un login expuesto a credential stuffing, para que AAP genere senales en vivo.

Flujo que ilumina en Datadog:
  request -> Flask (este codigo) -> query a Postgres
  - /search?q=...   : SQLi via f-string (linea marcada abajo) -> Code Security / IAST
  - /login          : credential stuffing -> senal de ATO
"""
import json
import logging
import os
import sys
import time

import psycopg2
from flask import Flask, request, jsonify

app = Flask(__name__)

# --- Logging JSON para Cloud SIEM ---------------------------------------------
# Emitimos logs con los atributos estandar de Datadog (evt.*, usr.*, network.*)
# para que las detection rules out-of-the-box (credential stuffing, brute force)
# hagan match sin necesidad de una regla custom.
_logger = logging.getLogger("prosperia")
_logger.setLevel(logging.INFO)
_handler = logging.StreamHandler(sys.stdout)
_handler.setFormatter(logging.Formatter("%(message)s"))
_logger.addHandler(_handler)
_logger.propagate = False


def client_ip():
    """IP real del cliente (respeta X-Forwarded-For detras del balanceador)."""
    xff = request.headers.get("X-Forwarded-For", "")
    if xff:
        return xff.split(",")[0].strip()
    return request.remote_addr or "unknown"


def log_security_event(category, name, outcome, usr_id=None, status=None):
    event = {
        "timestamp": int(time.time() * 1000),
        "status": "info" if outcome == "success" else "warn",
        "message": f"{name} {outcome}",
        "service": os.environ.get("DD_SERVICE", "prosperia-patient-api"),
        "evt": {"category": category, "name": name, "outcome": outcome},
        "network": {"client": {"ip": client_ip()}},
        "http": {
            "method": request.method,
            "url": request.path,
            "status_code": status,
            "useragent": request.headers.get("User-Agent", ""),
        },
    }
    if usr_id:
        event["usr"] = {"id": usr_id}
    _logger.info(json.dumps(event))


def get_conn():
    return psycopg2.connect(
        host=os.environ.get("PGHOST", "db"),
        dbname=os.environ.get("PGDATABASE", "prosperia"),
        user=os.environ.get("PGUSER", "prosperia"),
        password=os.environ.get("PGPASSWORD", "prosperia"),
    )


@app.get("/")
def health():
    return jsonify(status="ok", service="prosperia-patient-api")


@app.get("/search")
def search():
    """Buscador de pacientes. VULNERABLE a SQLi a proposito."""
    q = request.args.get("q", "")
    conn = get_conn()
    cur = conn.cursor()
    # >>> LINEA VULNERABLE: f-string concatena input del usuario en el SQL.
    # Esta es la linea exacta que IAST / Code Security resalta en el paso 8.
    query = f"SELECT id, name, record FROM patients WHERE name ILIKE '%{q}%'"
    cur.execute(query)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(results=[{"id": r[0], "name": r[1], "record": r[2]} for r in rows])


@app.post("/login")
def login():
    """Login expuesto a credential stuffing -> senal de ATO en AAP."""
    data = request.get_json(silent=True) or request.form
    username = data.get("username", "")
    password = data.get("password", "")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM users WHERE username = %s AND password = %s",
        (username, password),
    )
    user = cur.fetchone()
    cur.close()
    conn.close()
    if user:
        # evt.outcome=success -> login valido
        log_security_event("authentication", "login", "success",
                           usr_id=username, status=200)
        return jsonify(status="ok", user_id=user[0])
    # evt.outcome=failure -> esto es lo que acumula la detection rule de ATO
    log_security_event("authentication", "login", "failure",
                       usr_id=username, status=401)
    return jsonify(status="unauthorized"), 401


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
