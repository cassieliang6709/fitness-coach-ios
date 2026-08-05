FROM node:22-slim

WORKDIR /app

# 直接装平台特定的 workerd 二进制包
RUN npm install @cloudflare/workerd-linux-64 @anthropic-ai/sdk --no-save --no-package-lock

# 拷贝源码和配置
COPY src ./src
COPY wrangler.jsonc tsconfig.json ./
COPY schema.sql seed-exercises.sql seed-names.sql ./

EXPOSE 8788

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

# workerd 二进制在 @cloudflare/workerd-linux-64/bin/workerd
CMD ["/app/node_modules/@cloudflare/workerd-linux-64/bin/workerd", "serve", \
     "--socket-addr=entry=0.0.0.0:8788", \
     "wrangler.jsonc"]
