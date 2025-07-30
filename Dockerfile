# Dockerfile for testing Matcha on Linux
FROM swift:5.10-jammy

# Install additional dependencies if needed
RUN apt-get update && apt-get install -y \
    libncurses5-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy package files first for better caching
COPY Package.swift Package.resolved* ./

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests
COPY Examples ./Examples

# Build the project
RUN swift build -c release

# Run tests
RUN swift test

# Set up for interactive use
ENV TERM=xterm-256color

# Default to running the Counter example
CMD ["swift", "run", "Counter"]