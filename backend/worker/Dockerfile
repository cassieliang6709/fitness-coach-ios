FROM node:22-alpine

WORKDIR /app

# 安装依赖（wrangler + workerd）
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# 拷贝源码和配置
COPY src ./src
COPY wrangler.jsonc tsconfig.json ./

# D1 数据库 schema（首次启动需要 migrate）
COPY schema.sql seed-exercises.sql seed-names.sql ./

EXPOSE 8788

# wrangler dev 监听 0.0.0.0，生产模式下用 --local 走 workerd
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["npx", "wrangler", "dev", "--local", "--ip", "0.0.0.0", "--port", "8788"]
