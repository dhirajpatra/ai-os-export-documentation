# ============================================================
# TradeOS Frontend — Multi-Stage Docker Build
# Stage 1: Node.js builder (installs deps + builds Next.js)
# Stage 2: Nginx production server (serves static export)
# ============================================================

# ── Stage 1: Builder ────────────────────────────────────────
FROM node:20-alpine AS builder

# Install libc compatibility shims needed by some native modules
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Copy dependency manifests first (layer-cache optimization)
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./

# Install dependencies using the correct package manager
RUN \
  if [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable && pnpm install --frozen-lockfile; \
  else npm ci; \
  fi

# Copy the rest of the source code
COPY . .

# ── Build-time environment variables ──────────────────────
# These are baked into the Next.js bundle at build time.
# Override at build time with: --build-arg NEXT_PUBLIC_API_URL=...
ARG NEXT_PUBLIC_API_URL=http://localhost:8000
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

# Build the Next.js app
# If you use `next export` (static HTML), add: && npm run export
RUN npm run build

# ── Stage 2: Production Nginx Server ────────────────────────
FROM nginx:1.27-alpine AS runner

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# ── For Next.js with standalone output mode ──────────────────
# If next.config.js sets output: 'standalone', use this block instead
# and switch to a Node runtime (see alternative Dockerfile below).

# Copy built static assets from builder
# Adjust path if your Next.js outputs to a different directory
COPY --from=builder /app/.next/static /usr/share/nginx/html/_next/static
COPY --from=builder /app/public        /usr/share/nginx/html

# ── Health check ─────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:80/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
