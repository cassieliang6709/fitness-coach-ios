FROM node:22-alpine

WORKDIR /app

# 安装依赖（只要 workerd，不要 wrangler）
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && \
    # 手动安装 workerd（生产环境只需要这个）
    npm install workerd --no-save

# 拷贝源码和配置
COPY src ./src
COPY wrangler.jsonc tsconfig.json ./
COPY schema.sql seed-exercises.sql seed-names.sql ./

EXPOSE 8788

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

# 直接用 workerd，不走 wrangler（避免 npx 下载）
CMD ["node_modules/.bin/workerd", "serve", "--binary", "--experimental", \
     "--socket-addr=entry=0.0.0.0:8788", \
     "--external-addr=loopback=127.0.0.1:50510", \
     "--control-fd=3", \
     "wrangler.jsonc"]
