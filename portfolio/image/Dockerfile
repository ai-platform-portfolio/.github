FROM python:3.13-alpine@sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt \
    && pip uninstall --yes pip \
    && rm -rf /usr/local/lib/python3.13/ensurepip \
    && addgroup -S portfolio \
    && adduser -S -G portfolio portfolio

COPY app.py .
COPY static ./static

# Reuse the shared cleanup entrypoint in the web/job image.
ADD --chown=portfolio:portfolio https://raw.githubusercontent.com/ai-platform-portfolio/ops-shared/ef2c9ebe3df131f3bf2a92c2a86e360dad95c5e6/.github/actions/container-app-preview/preview_cleanup.py /app/preview_cleanup.py
RUN echo "3fede89e27426dd8cdff797019f49dbdcadd1b1d4da9412b36704024c0aa1a17  /app/preview_cleanup.py" | sha256sum -c -

USER portfolio

EXPOSE 8080

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
