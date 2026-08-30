FROM node:22-alpine

WORKDIR /app

COPY server.mjs ./server.mjs
COPY public ./public

ENV NODE_ENV=production
EXPOSE 8080

USER node

CMD ["node", "server.mjs"]
