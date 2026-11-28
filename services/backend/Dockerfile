# syntax=docker/dockerfile:1
# TaskFlow backend (Node 24 + Express). Build context: services/backend
#   docker build -t taskflow-backend:local services/backend
# Stage 1 installs production dependencies only; stage 2 is the runtime image, which has no npm,
# runs as the non-root "node" user and cannot change its own code (files are owned by root).

FROM node:26.13.1-alpine3.24 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM node:26.13.1-alpine3.24 AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app
# The app never needs a package manager at runtime: removing them shrinks the image and the CVE surface.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
    /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
    /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER node
EXPOSE 3000
# Liveness only: /api/health never touches the DB (ARCHITECTURE §3.2).
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
CMD ["node", "src/server.js"]
