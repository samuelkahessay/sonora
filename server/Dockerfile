# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm install --save-dev typescript tsx
RUN npm run build

# Production stage
FROM node:20-alpine AS production
RUN addgroup -g 1001 -S nodejs
RUN adduser -S sonora -u 1001
WORKDIR /app
COPY --from=builder --chown=sonora:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=sonora:nodejs /app/dist ./dist
COPY --chown=sonora:nodejs package*.json ./
RUN mkdir -p uploads && chown sonora:nodejs uploads
USER sonora
EXPOSE 8080
CMD ["node", "dist/server.js"]