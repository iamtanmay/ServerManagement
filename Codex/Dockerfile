#cp -r /home/maelnetbook/.codex/ ./codex-config/ && docker build -t codex-cli:latest . && rm -rf ./codex-config/
#docker run -it -v "$(pwd)":/workspace codex-cli:latest codex --profile Qwen_36_35B_MTP --yolo

FROM node:22-slim

# Install system dependencies needed by Codex
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install the OpenAI Codex CLI globally
RUN npm install -g @openai/codex

COPY ./codex-config/ /root/.codex/

# Set up the workspace folder
WORKDIR /workspace

# Run Codex by default
CMD ["codex"]
