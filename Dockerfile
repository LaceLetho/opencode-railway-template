FROM node:22-bookworm

ENV NODE_ENV=production
ARG OPENCODE_REF=v1.3.0

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    bash \
    procps \
  && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Verify bun
RUN bun --version

# Build OpenCode from source so the frontend and backend always come from the same ref.
ENV OPENCODE_SOURCE_DIR="/opt/opencode"
RUN ref="${OPENCODE_REF}" \
  && git clone https://github.com/anomalyco/opencode "${OPENCODE_SOURCE_DIR}" \
  && cd "${OPENCODE_SOURCE_DIR}" \
  && git checkout "${ref}" \
  && bun install \
  && bun run --cwd packages/opencode build --single

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install

# Copy start script, server wrapper, launch helper, websocket proxy helper, and monitor script
COPY start.sh server.js launch.js ws-proxy.js monitor.sh ./
RUN chmod +x monitor.sh

# Railway injects PORT at runtime
EXPOSE 8080

CMD ["sh", "start.sh"]
