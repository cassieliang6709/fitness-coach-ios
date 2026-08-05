# Build stage: TypeScript → JavaScript
FROM node:22-slim AS builder

WORKDIR /app

# 安装 build 依赖
COPY package.json package-lock.json ./
RUN npm ci

# 拷贝源码
COPY src ./src
COPY tsconfig.json ./

# 用 esbuild 打包成单文件
RUN npx esbuild src/index.ts --bundle --format=esm --target=es2022 \
    --external:cloudflare:* --external:node:* \
    --outfile=dist/index.js

# Runtime stage
FROM node:22-slim

WORKDIR /app

# 只装 workerd 运行时
RUN npm install @cloudflare/workerd-linux-64 --no-save --no-package-lock

# 从 builder 拿打包好的 JS
COPY --from=builder /app/dist ./dist

# 拷贝 workerd 配置
COPY config.capnp ./

EXPOSE 8788

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

# workerd 用 capnp 配置
CMD ["/app/node_modules/@cloudflare/workerd-linux-64/bin/workerd", "serve", "config.capnp"]
