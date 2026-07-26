FROM node:22-slim

# Install system dependencies needed by Codex
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode

ENTRYPOINT ["opencode"]
