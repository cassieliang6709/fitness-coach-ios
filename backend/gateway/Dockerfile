FROM node:22-alpine

WORKDIR /app

# 只拷贝 package.json，跳过 lockfile（无外部依赖）
COPY package.json ./
# 无第三方依赖，跳过 npm install

# 拷贝源码
COPY server.mjs coach-prompt.mjs gym-vision.mjs telemetry.mjs websocket-frames.mjs ./

EXPOSE 8787

# 容器内必须监听 0.0.0.0（默认是 127.0.0.1，外部无法访问）
ENV BIND_HOST=0.0.0.0 \
    PORT=8787 \
    NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8787/health', r => process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.mjs"]
