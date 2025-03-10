FROM python:3.11-slim

WORKDIR /app

COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/app.py .

ENV ENVIRONMENT=production
ENV VERSION=1.0.0

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"] 