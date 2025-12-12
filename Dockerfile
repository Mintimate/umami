# 构建阶段
FROM node:22-alpine AS builder

# 设置工作目录
WORKDIR /app

# 启用 Corepack 以使用 yarn
RUN corepack enable && corepack prepare yarn@stable --activate

# 设置 npm 镜像源
RUN npm config set registry https://mirrors.tencent.com/npm/

# 复制项目文件（包括 package.json）
COPY . .

# 设置 Yarn 使用腾讯云镜像源，并降低并发减少内存使用
RUN yarn config set npmRegistryServer https://mirrors.tencent.com/npm/ && \
    yarn config set unsafeHttpWhitelist mirrors.tencent.com && \
    yarn config set httpTimeout 120000 && \
    yarn config set networkConcurrency 2

# 设置 Node.js 内存限制，降低并发以减少内存使用
ENV NODE_OPTIONS="--max-old-space-size=2048"

# 安装依赖（使用 --mode=skip-build 跳过 postinstall 脚本中的编译，减少内存占用）
RUN yarn install --mode=skip-build

# 构建应用
RUN yarn build

# 生产阶段
FROM node:22-alpine AS runner

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=3000

# 启用 Corepack 以使用 yarn
RUN corepack enable && corepack prepare yarn@stable --activate

# 创建 umami 用户和组（使用较高的 UID 避免与宿主机用户冲突）
RUN addgroup --system --gid 10001 umami && \
    adduser --system --uid 10001 --ingroup umami umami

# 复制必要的文件
COPY --from=builder /app/package.json ./
COPY --from=builder /app/.env ./
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/geo ./geo

# 复制构建产物
COPY --from=builder --chown=umami:umami /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules

# 切换到 umami 用户
USER umami

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["yarn", "start"]
    