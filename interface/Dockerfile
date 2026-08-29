# Own base lineage. Nothing is shared with the pipeline image: the Python/C++
# toolchain has no business in a public-facing web container.
FROM node:22-slim AS deps
WORKDIR /app
COPY interface/package.json interface/package-lock.json* ./
RUN npm install --omit=dev

FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY interface/ ./
USER node
EXPOSE 3000
CMD ["node", "server/index.js"]
