# One image, three roles (api, worker, mock-psp), selected by the command.

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
COPY src/db/migrations ./dist/db/migrations
# Least privilege: never run as root inside the container.
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
