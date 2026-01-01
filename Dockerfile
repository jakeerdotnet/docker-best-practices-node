# Multi-stage build - GOOD PRACTICE
# Stage 1: Builder
# Using specific version instead of 'latest' (Mistake #11: Version Tags)
FROM node:18.17.1-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files only (Mistake #4: Layer Caching)
# This allows Docker to cache dependency installation
COPY package*.json ./

# Install production dependencies
# Using --only=production to exclude dev dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application source
COPY . .

# Stage 2: Production
# Using Alpine for smaller image size (Mistake #1: Bloated Images)
# Exact version pinning for reproducibility
FROM node:18.17.1-alpine AS production

# Install dumb-init for proper signal handling (Mistake #10: K8s optimization)
# dumb-init helps forward signals to the Node process
RUN apk add --no-cache dumb-init

# Set working directory
WORKDIR /app

# Copy built application and dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/src ./src

# Create non-root user (Mistake #2: Running as Root)
# Using specific UID/GID for better compatibility
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port (informational only)
EXPOSE 3000

# Health check (Mistake #6: Single Point of Failure)
# --interval: Check every 30 seconds
# --timeout: Wait up to 3 seconds for response
# --start-period: Give app 60 seconds to start
# --retries: Mark unhealthy after 3 failed checks
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})" || exit 1

# Use dumb-init as PID 1 for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Default command
CMD ["node", "src/server.js"]

# Labels for metadata
LABEL org.opencontainers.image.title="Docker Best Practices App"
LABEL org.opencontainers.image.description="Production-ready Node.js app demonstrating Docker best practices"
LABEL org.opencontainers.image.version="1.0.0"
