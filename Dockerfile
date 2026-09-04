FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN addgroup --system steam && adduser --system --ingroup steam steam \
    && pip install --no-cache-dir steam-mcp==1.14.0

WORKDIR /app
COPY --chown=steam:steam app.py /app/app.py

USER steam
EXPOSE 4100
CMD ["python", "/app/app.py"]
