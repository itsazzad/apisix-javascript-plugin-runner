# Builder stage
FROM node:18.12.0 as builder

# Install Deno
COPY --from=denoland/deno:1.39.4 /usr/bin/deno /usr/bin/deno

# Set noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive

# Use USTC mirror for apt-get
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

# Install required dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    clang \
    git \
    openssh-client \
    unzip \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Copy the application code
COPY . /usr/local/apisix/javascript-plugin-runner

# Set working directory
WORKDIR /usr/local/apisix/javascript-plugin-runner

# Install Node.js dependencies and build the application
RUN npm install && \
    make build

# Final stage
FROM apache/apisix:${APISIX_IMAGE_TAG:-3.8.0-debian}

# Use USTC mirror for apk
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories

# Copy Node.js and npm binaries from the builder stage
COPY --from=node:18.12.0-alpine /usr/local/include/node /usr/local/include/node
COPY --from=node:18.12.0-alpine /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node:18.12.0-alpine /usr/local/bin/node /usr/local/bin/node

# Create symbolic links for npm and npx
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Copy the built application from the builder stage
COPY --from=builder /usr/local/apisix/javascript-plugin-runner /usr/local/apisix/javascript-plugin-runner
