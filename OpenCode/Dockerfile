FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# .NET
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && chmod +x dotnet-install.sh \
    && ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm dotnet-install.sh


ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=$PATH:$DOTNET_ROOT

RUN npm install -g opencode-ai

ENTRYPOINT ["opencode"]
