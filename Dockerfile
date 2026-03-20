# Stage 1: build with Node + Yarn + Vite
FROM node:20-slim AS builder

# Native deps: node-gyp, canvas (Cairo/Pango), sharp (libvips)
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpixman-1-dev \
    libvips-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# # Copy package files first for better layer caching
COPY package.json yarn.lock ./

# # Enable corepack for yarn
RUN corepack enable
# Use node-modules linker in Docker to avoid PnP virtual path issues
ENV YARN_NODE_LINKER=node-modules
RUN yarn set version stable && \
    yarn install --immutable

# Copy source code and config files
COPY . .

# Verify install
RUN test -d node_modules && test -d node_modules/vite || (echo "ERROR: Install failed!" && exit 1)

# BUILD_ENV: use env/dev.env or env/prod.env (default prod). Pass e.g. --build-arg BUILD_ENV=dev when building.
ARG BUILD_ENV=prod
COPY env/${BUILD_ENV}.env .env
RUN yarn build

# Stage 2: serve with nginx
FROM nginx:alpine AS runner

# SPA: fallback to index.html for client-side routing (nginx default port 80)
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
