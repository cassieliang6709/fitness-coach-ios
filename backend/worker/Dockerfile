FROM node:22-alpine

WORKDIR /app

# 用生产版 package.json（去掉 wrangler，避免 npx 触发下载）
COPY package.prod.json package.json
COPY package-lock.json ./

# 只安装生产依赖 + workerd
RUN npm ci --omit=dev && \
    npm install workerd --no-save

# 拷贝源码和配置
COPY src ./src
COPY wrangler.jsonc tsconfig.json ./
COPY schema.sql seed-exercises.sql seed-names.sql ./

EXPOSE 8788

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8788/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

# 直接用 workerd 绝对路径
CMD ["/app/node_modules/workerd/bin/workerd", "serve", "--binary", "--experimental", \
     "--socket-addr=entry=0.0.0.0:8788", \
     "--external-addr=loopback=127.0.0.1:50510", \
     "--control-fd=3", \
     "wrangler.jsonc"]
