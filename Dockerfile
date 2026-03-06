FROM node:22-bookworm

ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
  && rm -rf /var/lib/apt/lists/*

# Install openwork-orchestrator (ships with pre-compiled Linux binary; Bun not needed at runtime)
RUN npm install -g openwork-orchestrator && npm cache clean --force

# Persist openwork sidecar cache to Railway volume by default
ENV OPENWORK_SIDECAR_DIR=/data/sidecars
ENV OPENWORK_DATA_DIR=/data/openwork
ENV OPENCODE_WORKSPACE=/data/workspace

WORKDIR /app

# Install proxy server deps
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY start.sh ./

# Railway injects PORT at runtime. Do not hardcode a default.
EXPOSE 8080

ENTRYPOINT ["tini", "--"]
CMD ["bash", "start.sh"]
