# syntax=docker/dockerfile:1
# gods-eye-view — keyless static build (tier 1: no API keys, no backend).
# Upstream (https://github.com/bilawalsidhu/gods-eye-view) publishes no image
# or Dockerfile, so we build the Vite SPA here and serve dist/ with a tiny
# Node stdlib server (server.js). No nginx: cluster ingress is Gateway API.
# Pinned to a known-good upstream main commit (see UPSTREAM_REF).
ARG UPSTREAM_REF=759652207fd1279ece97f0f19af566feb9a82146

FROM node:24-slim AS build
ARG UPSTREAM_REF
# Puppeteer (devDependency) would download Chrome; only `vite build` runs here.
ENV PUPPETEER_SKIP_DOWNLOAD=1
WORKDIR /src
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/bilawalsidhu/gods-eye-view.git . \
 && git fetch --depth 1 origin "$UPSTREAM_REF" \
 && git checkout "$UPSTREAM_REF"
RUN npm ci --no-audit --no-fund \
 && npm run build \
 && node -e "const p=require('./package.json'); console.log('built', p.name, p.version)"

FROM node:24-slim
ARG UPSTREAM_REF
LABEL org.opencontainers.image.source="https://github.com/bilawalsidhu/gods-eye-view" \
      org.opencontainers.image.revision="${UPSTREAM_REF}" \
      org.opencontainers.image.title="gods-eye-view (keyless static)"
WORKDIR /app
COPY --from=build /src/dist ./dist
COPY server.js ./
EXPOSE 4173
USER node
CMD ["node", "server.js"]
