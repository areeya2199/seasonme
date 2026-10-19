# Python image and native-library versions verified during Phase B.
FROM python:3.12.1-slim-bookworm@sha256:a64ac5be6928c6a94f00b16e09cdf3ba3edd44452d10ffa4516a58004873573e

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HOME=/tmp \
    MPLCONFIGDIR=/tmp/matplotlib \
    PORT=10000

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libxcb1=1.15-1 \
        libgl1=1.6.0-1 \
        libglib2.0-0=2.74.6-2+deb12u9 \
        libgles2=1.6.0-1 \
        libegl1=1.6.0-1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-render.txt ./requirements-render.txt
RUN python -m pip install --no-cache-dir -r requirements-render.txt \
    && python -m pip check

# Explicit copies keep credentials, local environments and tests out of layers.
COPY main.py ./main.py
COPY services/analysis.py services/auth.py ./services/
COPY models/face_landmarker.task ./models/face_landmarker.task

USER 10001:1000

EXPOSE 10000

# Expand Render's PORT at container startup; exec forwards shutdown signals.
CMD ["sh", "-c", "exec python -m uvicorn main:app --host 0.0.0.0 --port \"$PORT\" --workers 1"]
