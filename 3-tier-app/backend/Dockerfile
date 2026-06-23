FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
ENV PORT=8080
WORKDIR /app
RUN addgroup -g 10001 -S app && adduser -u 10001 -S -G app app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./
USER 10001
EXPOSE 8080
CMD ["node", "server.js"]
