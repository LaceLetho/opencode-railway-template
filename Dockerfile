FROM node:22-bookworm

ENV NODE_ENV=production
ENV OPENCODE_SOURCE_DIR="/opt/opencode"
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bash \
    gh \
    git \
    procps \
  && rm -rf /var/lib/apt/lists/*

# Pin Bun to the version in packages/opencode `packageManager`; a floating install
# silently drifted to 1.4.4 and broke `bun install` (photon-node patch hunk #10).
ARG BUN_VERSION=1.3.14
ARG OPENCODE_SOURCE_CACHE_BUST=20260602T113843Z
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" \
  && bun --version \
  && echo "opencode source cache bust: ${OPENCODE_SOURCE_CACHE_BUST}" \
  && git clone --branch railway --single-branch https://github.com/LaceLetho/opencode.git "${OPENCODE_SOURCE_DIR}" \
  && cd "${OPENCODE_SOURCE_DIR}" && git fetch origin railway && git reset --hard origin/railway \
  && cd "${OPENCODE_SOURCE_DIR}" \
  && version="$(node -p "require('./packages/opencode/package.json').version")" \
  && OPENCODE_VERSION="${version}" OPENCODE_CHANNEL=latest bun install \
  && OPENCODE_VERSION="${version}" OPENCODE_CHANNEL=latest bun run --cwd packages/app build \
  && OPENCODE_VERSION="${version}" OPENCODE_CHANNEL=latest bun run --cwd packages/opencode build --single \
  && install -m 755 "$(find "${OPENCODE_SOURCE_DIR}/packages/opencode/dist" -type f -path "*/bin/opencode" | head -n 1)" /usr/local/bin/opencode

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install

# Copy start script, server wrapper, runtime config helpers, oh-my templates, and monitor script
COPY start.sh server.js plugin-refresh.js runtime-config.js oh-my-opencode*.json launch.js ws-proxy.js monitor.sh ./
RUN chmod +x monitor.sh

# Railway injects PORT at runtime
EXPOSE 8080

CMD ["sh", "start.sh"]
