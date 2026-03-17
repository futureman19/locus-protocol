FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist
COPY src/db/migrations ./src/db/migrations

ENV NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health >/dev/null || exit 1

CMD ["node", "dist/index.js"]
