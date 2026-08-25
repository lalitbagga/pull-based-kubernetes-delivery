FROM node:24.12.0-alpine@sha256:c921b97d4b74f51744057454b306b418cf693865e73b8100559189605f6955b8

ARG APP_VERSION=development

ENV NODE_ENV=production \
    PORT=8080 \
    APP_VERSION=${APP_VERSION}

LABEL org.opencontainers.image.title="delivery-api" \
      org.opencontainers.image.description="Pull-based Kubernetes delivery lab workload" \
      org.opencontainers.image.revision="${APP_VERSION}"

WORKDIR /app

COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

USER node

EXPOSE 8080

CMD ["node", "src/server.js"]
