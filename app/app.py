"""
Lab AAP ProsperIA — app deliberadamente vulnerable para demo de Datadog App & API Protection.

NO USAR EN PRODUCCION. Contiene una SQL injection a proposito (parametro `q`)
y un login expuesto a credential stuffing, para que AAP genere senales en vivo.

Flujo que ilumina en Datadog:
  request -> Flask (este codigo) -> query a Postgres
  - /search?q=...   : SQLi via f-string (linea marcada abajo) -> Code Security / IAST
  - /login          : credential stuffing -> senal de ATO
"""
import os
import psycopg2
from flask import Flask, request, jsonify

app = Flask(__name__)


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
        return jsonify(status="ok", user_id=user[0])
    return jsonify(status="unauthorized"), 401


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
