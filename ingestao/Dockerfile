FROM python:3.12-slim

# Saída sem buffer: os prints aparecem na hora no Cloud Logging
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Argumentos (--anos, --etapas) podem ser passados na execução do job
ENTRYPOINT ["python", "main.py"]
