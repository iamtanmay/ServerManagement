# =============================================================================
# OpenCode Web - Generic Docker Image
# =============================================================================
# A prefix-aware Web UI for OpenCode that works behind reverse proxies.
# Supports dynamic URL prefixes via BASE_PATH environment variable.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build the UI (Clones and builds entirely inside Docker)
# -----------------------------------------------------------------------------
FROM oven/bun:1-alpine AS builder

# Install git to allow cloning
RUN apk add --no-cache git

WORKDIR /build

# Clone the repository directly inside the build stage
RUN git clone https://github.com/prokube/pk-opencode-webui.git .

# Install dependencies and build the frontend application
WORKDIR /build/app-prefixable
RUN bun install
RUN bun run build

# -----------------------------------------------------------------------------
# Stage 2: Runtime (Clean and lightweight, no source code or git history)
# -----------------------------------------------------------------------------
FROM oven/bun:1-alpine

# Install minimal runtime dependencies
RUN apk add --no-cache \
    bash \
    git \
    curl \
    openssh-client

# Create clean application directories
RUN mkdir -p /opt/opencode-ui /opt/shared

# Copy ONLY the built frontend assets from the builder stage
COPY --from=builder /build/app-prefixable/dist /opt/opencode-ui/dist

# Copy the server script and shared modules required for runtime
COPY --from=builder /build/docker/serve-ui.ts /opt/opencode-ui/serve-ui.ts
COPY --from=builder /build/shared /opt/shared

# Environment configuration
ENV PORT=8080 \
    API_URL=http://127.0.0.1:4096 \
    BASE_PATH=/

WORKDIR /opt/opencode-ui
EXPOSE 8080

# Start the UI server using Bun
CMD ["bun", "run", "serve-ui.ts"]

