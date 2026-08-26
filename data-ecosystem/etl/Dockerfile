FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir psycopg2-binary

COPY load_dw.py .

ENV DATALAKE_DIR=/datalake
ENV SQL_DIR=/sql

CMD ["python", "load_dw.py"]
