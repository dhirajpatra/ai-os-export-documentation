# ============================================================
# TradeOS Frontend — Vite + React
# Stage 1: Node.js builder  → vite build → dist/
# Stage 2: Nginx            → serves dist/ as static files
# ============================================================

# ── Stage 1: Builder ────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first (layer-cache optimisation)
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm ci

# Copy the rest of the source
COPY . .

# Build-time env var — baked into the JS bundle by Vite
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=${VITE_API_URL}

# Produce the production build → /app/dist
RUN npm run build

# ── Stage 2: Nginx ──────────────────────────────────────────
FROM nginx:1.27-alpine AS runner

# Remove the default nginx site config
RUN rm /etc/nginx/conf.d/default.conf

# Bring in our custom config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the Vite build output into Nginx's web root
COPY --from=builder /app/dist /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fs http://127.0.0.1:80/ -o /dev/null || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
