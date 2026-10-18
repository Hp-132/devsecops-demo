FROM python:3.13-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

# INTENTIONAL: no USER instruction -> container runs as root.
# Hadolint (DL3002) will flag this, and Kyverno will block it at deploy time.
USER root
EXPOSE 5000
CMD ["python", "app.py"]
