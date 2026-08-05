FROM node:22-alpine

WORKDIR /app

# 手动下载 workerd 二进制（不用 npm，避免触发 wrangler）
RUN apk add --no-cache curl && \
    curl -L https://github.com/cloudflare/workerd/releases/download/v1.20260805.1/workerd-linux-64.gz -o /tmp/workerd.gz && \
    gunzip /tmp/workerd.gz && \
    mv /tmp/workerd /usr/local/bin/workerd && \
    chmod +x /usr/local/bin/workerd && \
    apk del curl

# 只装 @anthropic-ai/sdk（唯一运行时依赖）
RUN npm install @anthropic-ai/sdk --no-save --no-package-lock

# 拷贝源码和配置
COPY src ./src
COPY wrangler.jsonc tsconfig.json ./
COPY schema.sql seed-exercises.sql seed-names.sql ./

EXPOSE 8788

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

# 直接用 workerd 绝对路径
CMD ["/usr/local/bin/workerd", "serve", "--binary", "--experimental", \
     "--socket-addr=entry=0.0.0.0:8788", \
     "--external-addr=loopback=127.0.0.1:50510", \
     "--control-fd=3", \
     "wrangler.jsonc"]
