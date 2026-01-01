# Docker Build Optimization Guide

## Image Size Analysis

### Before Optimization
- Base image (Ubuntu): 200MB
- Node.js and npm: 400MB
- Development dependencies: 800MB
- Application code: 12MB
- **Total: 1.4GB** ❌

### After Optimization (This Project)
- Base image (Alpine): 35MB
- Node.js and npm: 90MB
- Production dependencies only: 25MB
- Application code: 12MB
- **Total: 162MB** ✅

**Reduction: 88%** (1.4GB → 162MB)

## Multi-Stage Build Explanation

### Builder Stage
```dockerfile
FROM node:18.17.1-alpine AS builder
# Install ALL dependencies (dev + production)
# Build application
# No cleanup needed - we'll discard this stage
```

### Production Stage
```dockerfile
FROM node:18.17.1-alpine AS production
# Copy ONLY node_modules from builder (production only)
# Copy application code
# Create non-root user
# Add health checks
# Start as non-root
```

### Key Benefits
1. Development tools not in final image
2. Cache layers for faster rebuilds
3. Reduced attack surface
4. Faster deployment

## Layer Caching Strategy

### Optimal Dockerfile Order
```
1. FROM (base image)
2. System dependencies (apt, apk - rarely change)
3. Environment setup
4. COPY package files
5. RUN npm install (cached separately)
6. COPY application code (changes frequently)
7. Configure user and ports
8. Health checks
```

### Why This Order?
- **System deps**: Install once, rarely update
- **Package files**: Changes monthly, triggers rebuild
- **Application code**: Changes daily, should NOT rebuild deps

### Build Time Comparison
```
Poor ordering:  15-20 minutes per build
Optimized:      2-3 minutes per build
First run:      ~8 minutes (downloads everything)
Code change:    ~1 minute (reuses cached layers)
```

## Docker Ignore Best Practices

### What to Exclude
```
node_modules/           - Will be installed in container
.git/                   - Version control history
.env                    - Secrets (never commit)
coverage/               - Test coverage reports
dist/                   - Build outputs
npm-debug.log           - Debug logs
.nyc_output/            - Coverage data
.DS_Store               - macOS system files
```

### Impact
- Build context: Typically 2GB → 50-100MB
- Build time: 5+ minutes → <1 minute
- Network transfer: 97% faster

## Security Considerations

### Non-Root User Benefits
✅ Prevents container escape to host
✅ Limits damage from compromised container
✅ Compliance requirements (PCI-DSS, SOC2)
✅ Kubernetes security policies

### UID/GID Selection
```dockerfile
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs
```

Why 1001?
- UID 0: Root (never use)
- UID 1: System reserved
- UID 1001+: Application user safe zone

## Health Check Best Practices

### HEALTHCHECK Instruction
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:3000/health
```

Parameters:
- `--interval`: How often to check (30s)
- `--timeout`: Wait for response (3s)
- `--start-period`: Initial grace period (60s)
- `--retries`: Failed attempts before unhealthy (3)

### Kubernetes Probes
1. **Liveness**: Is app running? (restart if failed)
2. **Readiness**: Can app handle traffic? (remove from LB if failed)
3. **Startup**: Has app finished starting? (delay liveness checks)

## Signal Handling

### Why It Matters
1. **Docker stop**: Sends SIGTERM, 10 seconds timeout
2. **K8s shutdown**: Sends SIGTERM, 30 seconds timeout
3. **Graceful shutdown**: Close connections, save state

### Implementation
```javascript
process.on('SIGTERM', () => {
  console.log('Shutting down...');
  server.close(() => {
    process.exit(0);  // Exit after server closes
  });
});
```

### What NOT to Do
```javascript
// ❌ Don't ignore signals
// ❌ Don't exit immediately
// ❌ Don't hang indefinitely
```

## Resource Management

### Memory Limits
- **Limit**: Maximum memory container can use (512M)
- **Request**: Minimum guaranteed memory (256M)
- Why? Prevent OOMKilled, enable fair scheduling

### CPU Limits
- **Limit**: Max CPU allowed (0.5 CPU)
- **Request**: Minimum guaranteed CPU (0.25 CPU)
- Why? Prevent CPU starvation, enable throttling

### Practical Values
For Node.js apps:
- Small app: 256M limit, 128M request
- Medium app: 512M limit, 256M request
- Large app: 1G limit, 512M request

Monitor with: `docker stats` or `kubectl top pods`

## Logging Best Practices

### Structured Logging (JSON)
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "info",
  "service": "app",
  "method": "GET",
  "path": "/api/users",
  "status": 200,
  "duration": "45ms"
}
```

Benefits:
- Searchable in log aggregators
- Machine parseable
- Easy to analyze

### Log Rotation
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"    # Rotate at 10MB
    max-file: "3"      # Keep 3 files
```

Prevents:
- Disk space issues
- Performance degradation
- Uncontrolled file growth

## Environment Variable Management

### DO
```dockerfile
ENV NODE_ENV production
ENV PORT 3000
```

### DON'T
```dockerfile
ENV DATABASE_PASSWORD "super_secret"
ENV API_KEY "sk_live_abc123"
```

### Better
Use Docker secrets or external management:
```bash
docker run --secret db_password myapp
```

## Version Pinning Strategy

### Development
- Use minor versions: `node:18-alpine`
- Get security patches automatically
- Some updates might break things

### Staging
- Use patch versions: `node:18.17-alpine`
- Control updates more precisely
- Test before production

### Production
- Use exact versions: `node:18.17.1-alpine`
- Pin SHA digests: `node:18@sha256:abc123...`
- Never use `latest`
- Never auto-update

## Multi-Platform Builds

### Why It Matters
- Development: Apple Silicon (ARM64)
- CI/CD: Linux x86_64 (AMD64)
- Production: Mixed environments

### buildx Setup
```bash
docker buildx create --name mybuilder --use
docker buildx build --platform linux/amd64,linux/arm64 -t app . --push
```

### Platform-Specific Concerns
```dockerfile
FROM --platform=$BUILDPLATFORM node:18-alpine AS builder

RUN case "$TARGETPLATFORM" in \
  "linux/amd64") apk add libc6-compat ;; \
  "linux/arm64") apk add libc6-compat ;; \
esac
```

## Container Scanning

### Vulnerability Types
1. **Known CVEs**: Published vulnerabilities
2. **Dependency issues**: Outdated packages
3. **Misconfigurations**: Security settings
4. **Compliance**: Regulatory violations

### Scanning Tools
- **Trivy**: Comprehensive, fast, free
- **Snyk**: Developer-focused, remediation advice
- **Docker Scout**: Docker-native scanning

### CI/CD Integration
```yaml
- name: Scan with Trivy
  run: trivy image --severity HIGH,CRITICAL myapp:latest
```

Fail builds on vulnerabilities: `exit 1` if high/critical found

## Kubernetes Readiness

### Container vs K8s Considerations

| Aspect | Docker | Kubernetes |
|--------|--------|------------|
| Process 1 | Optional | Required (signal handling) |
| Signals | Nice to have | Critical (SIGTERM) |
| Health checks | HEALTHCHECK | Probes (3 types) |
| Restart | Automatic | Conditional (liveness) |
| Secrets | Env files | K8s Secrets |
| Networking | Bridge/host | Service DNS |
| Storage | Volumes | PersistentVolumes |

### K8s-Ready Checklist
- [ ] Handles SIGTERM gracefully
- [ ] Responds to health probes
- [ ] Uses environment variables
- [ ] Writes logs to stdout/stderr
- [ ] No hardcoded localhost
- [ ] No persistent state in container
- [ ] Resource limits defined
- [ ] Security context applied
