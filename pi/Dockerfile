FROM node:22-bookworm-slim

# Install system dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep curl \
  && rm -rf /var/lib/apt/lists/*

# .NET 8.0
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && chmod +x dotnet-install.sh \
    && ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm dotnet-install.sh

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=$PATH:$DOTNET_ROOT

# Install Pi coding agent globally (as root, which is fine for global npm installs)
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Switch to the built-in 'node' user (UID 1000, GID 1000)
USER node
ENV HOME=/home/node

WORKDIR /workspace
ENTRYPOINT ["pi"]
