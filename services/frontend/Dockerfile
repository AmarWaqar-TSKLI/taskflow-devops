# syntax=docker/dockerfile:1
# TaskFlow frontend. Build context: services/frontend
#   docker build -t taskflow-frontend:local services/frontend
# Stage 1 bundles the static site with esbuild (`npm run build` -> dist/, including index.html).
# Stage 2 serves dist/ with nginx-unprivileged on 8080 as uid 101; no node, no npm in the final image.

FROM node:24.22.3-alpine3.24 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts && npm cache clean --force
COPY . .
RUN npm run build

FROM nginx/nginx-unprivileged:1.31.10-alpine3.24 AS runtime
# libxml2 in this base (2.13.9-r3) has HIGH CVEs fixed in 2.13.9-r5 (Trivy, 27 Nov). No newer base tag
# yet: upgrade just that package, then drop back to the unprivileged user. Remove once the base has it.
USER root
RUN apk upgrade --no-cache libxml2
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/
USER 101
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/health"]
