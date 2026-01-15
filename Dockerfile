# Donna AI Factory - Agent Container
# Base image: Node.js Slim for minimal footprint with claude-code support

FROM node:20-slim

# Metadata
LABEL maintainer="David <ddzuluagam@gmail.com>"
LABEL description="Claude Code Agent for Donna AI Factory"
LABEL version="1.0"

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production
ENV CLAUDE_CODE_SKIP_UPDATE_CHECK=true

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    openssh-client \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install claude-code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user for security
RUN useradd -m -s /bin/bash agent \
    && mkdir -p /home/agent/.ssh \
    && mkdir -p /home/agent/.config/claude-code \
    && chown -R agent:agent /home/agent

# Set up Git configuration
RUN git config --system --add safe.directory '*'

# Switch to non-root user
USER agent
WORKDIR /workspace

# Configure Git for the agent user
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global user.email "agent@donna-factory.local" \
    && git config --global user.name "Donna Agent"

# Copy entrypoint script
COPY --chown=agent:agent entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD which claude || exit 1

# Use entrypoint to fix worktree paths
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command: keep container alive in headless mode
CMD ["tail", "-f", "/dev/null"]
