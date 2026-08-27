# Build stage: TypeScript → JavaScript, while retaining Wrangler and its
# workerd/D1 runtime dependencies for the final local-Worker image.
FROM node:22-slim AS builder

WORKDIR /app

# 安装 build 依赖
COPY package.json package-lock.json ./
RUN npm ci

# 拷贝源码
COPY src ./src
COPY tsconfig.json ./

# 用 esbuild 打包成 service worker 格式（workerd 原生支持）
RUN npx esbuild src/index.ts --bundle --format=esm --target=es2022 \
    --external:cloudflare:* --external:node:* \
    --outfile=dist/index.js

# Runtime stage. Do not run bare `workerd`: its Cap'n Proto config does not
# provide the Worker secrets or the D1 binding that this application requires.
FROM node:22-slim

WORKDIR /app

# Node bundles a current trust store, while local workerd reads the operating
# system PEM store for outbound `fetch()`. Materialise Node's verified roots
# without an apt network dependency, then name that PEM file explicitly.
RUN mkdir -p /etc/ssl/certs \
    && node -e 'require("node:fs").writeFileSync("/etc/ssl/certs/ca-certificates.crt", require("node:tls").rootCertificates.join("\\n"))'

# Wrangler owns the local Worker binding layer. Copy its resolved dependency
# tree instead of downloading a second, unpinned runtime at container startup.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY wrangler.jsonc schema.sql seed-exercises.sql seed-names.sql ./
COPY docker-entrypoint.sh ./
RUN chmod 0555 ./docker-entrypoint.sh

EXPOSE 8788

ENV NODE_ENV=production
ENV BIND_HOST=0.0.0.0
ENV PORT=8788
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# The production Compose file injects secrets as process variables. Wrangler
# passes them to `env` only when explicitly asked to include the process env.
ENV CLOUDFLARE_INCLUDE_PROCESS_ENV=true

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

ENTRYPOINT ["./docker-entrypoint.sh"]
