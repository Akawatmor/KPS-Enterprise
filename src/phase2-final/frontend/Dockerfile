# syntax=docker/dockerfile:1

# ── deps: install dependencies ────────────────────────────────────────────────
FROM oven/bun:1.2-alpine AS deps
WORKDIR /app
COPY package.json bun.lock* ./
# RUN bun install --frozen-lockfile
RUN bun install

# ── builder: build Next.js standalone ────────────────────────────────────────
FROM oven/bun:1.2-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Accept at build time so NEXT_PUBLIC_ var is embedded in the JS bundle.
# Leave empty (default) for same-domain K3s deployments (relative /api paths).
ARG NEXT_PUBLIC_API_BASE_URL=""
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_TELEMETRY_DISABLED=1

RUN bun run build

# ── runner: minimal production image ─────────────────────────────────────────
FROM oven/bun:1.2-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN apk update && \
    apk upgrade --no-cache && \
    rm -rf /var/cache/apk/*

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
# Next.js standalone output (server.js) runs directly on Bun runtime
CMD ["bun", "server.js"]
