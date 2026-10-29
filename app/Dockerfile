FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

EXPOSE 8080

# ddtrace-run habilita APM + AAP (App & API Protection).
# El bloqueo por IP via Remote Config llega por el trace agent, sin redeploy.
CMD ["ddtrace-run", "gunicorn", "-b", "0.0.0.0:8080", "-w", "2", "app:app"]
