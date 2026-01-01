# Troubleshooting Guide

## Build Issues

### Build Timeout
**Problem**: Docker build takes >20 minutes
**Causes**: Large build context, no layer caching, slow network
**Solutions**:
```bash
# Check build context size
du -sh .

# Check .dockerignore
cat .dockerignore

# Enable BuildKit for better caching
DOCKER_BUILDKIT=1 docker build .

# Use --progress=plain for detailed output
docker build --progress=plain .
```

### Build Fails on Dependencies
**Problem**: npm install fails during build
**Causes**: Network issues, version conflicts, corrupted cache
**Solutions**:
```bash
# Clear npm cache
docker build --no-cache .

# Check package-lock.json
npm ci --verbose

# Use npm ci instead of npm install
# (already done in Dockerfile)
```

### Image Size Too Large
**Problem**: Image is >500MB
**Causes**: Non-Alpine base, dev dependencies included
**Solutions**:
```bash
# Analyze layers
docker history docker-best-practices-app:latest

# Check what's in image
docker run --rm docker-best-practices-app:latest \
  du -sh /* | sort -rh | head -10

# Rebuild with proper multi-stage setup
DOCKER_BUILDKIT=1 docker build .
```

## Container Runtime Issues

### Container Won't Start
**Problem**: Container exits immediately
**Symptoms**: `docker ps` doesn't show container, `docker logs` shows error
**Solutions**:
```bash
# Check logs
docker logs <container-id>

# Run in foreground to see errors
docker run --rm docker-best-practices-app:latest

# Check permissions
docker run --rm --user root docker-best-practices-app:latest id

# Test locally first
node src/server.js
```

### Container Crashes After Start
**Problem**: Container starts but then crashes
**Symptoms**: Status `Exited (1)` or constantly restarting
**Solutions**:
```bash
# Check previous logs
docker logs <container-id> --tail=50

# Run without health checks to focus on app
docker run --no-healthcheck docker-best-practices-app:latest

# Debug with shell
docker run -it --entrypoint sh docker-best-practices-app:latest
# Inside: node src/server.js (test manually)
```

### Port Not Accessible
**Problem**: Can't reach http://localhost:3000
**Causes**: Port not mapped, wrong port, firewall
**Solutions**:
```bash
# Check port mapping
docker port <container-id>

# Check if port is in use
lsof -i :3000  # macOS/Linux
netstat -ano | findstr :3000  # Windows

# Try accessing from container
docker exec <container-id> wget -O- http://localhost:3000/health

# Check listening ports
docker exec <container-id> ss -tlnp
```

### Memory or CPU Issues
**Problem**: Container slow or getting killed
**Symptoms**: OOMKilled, high resource usage
**Solutions**:
```bash
# Check resource usage
docker stats

# Check if hitting limits
docker inspect <container-id> | grep -A 10 '"Memory"'

# Increase limits
docker run -m 1G --cpus="1.0" docker-best-practices-app:latest

# Profile memory usage
docker run -it docker-best-practices-app:latest \
  node --inspect-brk src/server.js
```

## Docker Compose Issues

### Service Won't Start
**Problem**: Docker Compose exits with error
**Causes**: Port in use, invalid config, missing image
**Solutions**:
```bash
# Check syntax
docker-compose config

# Verbose output
docker-compose up --verbose

# Check logs for specific service
docker-compose logs app

# Rebuild images
docker-compose up --build

# Check ports
docker-compose ps
```

### Database Connection Fails
**Problem**: App can't connect to database
**Causes**: Service not ready, wrong hostname, firewall
**Solutions**:
```bash
# Check database is running
docker-compose ps db

# Test connectivity
docker-compose exec app sh
# Inside: curl http://db:5432  (should timeout, not refuse)

# Check service name in connection string
# Use: postgresql://user:pass@db:5432/dbname
# NOT: postgresql://user:pass@localhost:5432/dbname

# Wait for database to be ready
docker-compose up --wait

# Check database logs
docker-compose logs db
```

### Services Can't Communicate
**Problem**: One service can't reach another
**Causes**: Different networks, firewalls, DNS
**Solutions**:
```bash
# Check networks
docker network ls
docker network inspect docker-compose_frontend

# Test DNS
docker-compose exec app nslookup db

# Ping from service
docker-compose exec app ping db

# Check iptables (Linux)
sudo iptables -L -n

# Restart Docker daemon (last resort)
docker-compose down
docker system prune
docker-compose up
```

### Data Persists When It Shouldn't
**Problem**: Old data still there after `docker-compose down`
**Causes**: Named volumes retained
**Solutions**:
```bash
# Remove volumes
docker-compose down -v

# List volumes
docker volume ls | grep docker-best-practices

# Remove specific volume
docker volume rm <volume-name>

# Fresh restart
docker-compose down -v && docker-compose up
```

## Kubernetes Issues

### Pods Won't Start
**Problem**: Pods stuck in Pending/CrashLoopBackOff
**Causes**: Image not found, resource constraints, probe failures
**Solutions**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n docker-best-practices

# Check events
kubectl get events -n docker-best-practices --sort-by='.lastTimestamp'

# View logs
kubectl logs <pod-name> -n docker-best-practices -f

# Check image
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].imageID}'
```

### Liveness Probe Killing Pod
**Problem**: Pod keeps restarting due to liveness probe
**Causes**: Probe too aggressive, app slow to respond
**Solutions**:
```bash
# Increase initial delay
kubectl set probe deployment app liveness \
  --initial-delay-seconds=60 \
  -n docker-best-practices

# Test probe manually
kubectl exec -it <pod-name> -n docker-best-practices -- \
  wget -O- http://localhost:3000/health
```

### Readiness Probe Never Ready
**Problem**: Pod shows "0/1 ready"
**Causes**: Endpoint not responding, incorrect path, networking
**Solutions**:
```bash
# Test endpoint
kubectl exec -it <pod-name> -n docker-best-practices -- \
  wget -O- http://localhost:3000/ready

# Check logs
kubectl logs <pod-name> -n docker-best-practices | grep -i "ready\|error"

# Increase initial delay
kubectl set probe deployment app readiness \
  --initial-delay-seconds=10 \
  -n docker-best-practices
```

### Pod Can't Access Service
**Problem**: Pod can't reach another service
**Causes**: DNS, network policy, service not ready
**Solutions**:
```bash
# Test DNS
kubectl exec -it <pod-name> -n docker-best-practices -- \
  nslookup app-service.docker-best-practices.svc.cluster.local

# Check service
kubectl get svc -n docker-best-practices

# Test connectivity
kubectl exec -it <pod-name> -n docker-best-practices -- \
  wget -O- http://app-service:80/health

# Check network policies
kubectl get networkpolicy -n docker-best-practices
kubectl describe networkpolicy app-network-policy \
  -n docker-best-practices
```

### Resource Quota Exceeded
**Problem**: Can't create new pods, "Exceeded quota"
**Causes**: Namespace resource limits
**Solutions**:
```bash
# Check quota
kubectl describe resourcequota -n docker-best-practices

# Check current usage
kubectl describe nodes

# Reduce pod count or increase limits
kubectl set resources deployment app \
  --limits=memory=512Mi,cpu=500m \
  -n docker-best-practices
```

## Logging Issues

### No Logs in Container
**Problem**: `docker logs` shows nothing
**Causes**: App not logging to stdout, redirected elsewhere
**Solutions**:
```bash
# Check if app is writing logs
docker exec <container-id> ls -la /var/log/

# Check stdout/stderr
docker run -it docker-best-practices-app:latest \
  node src/server.js  # Should see logs

# Check application configuration
grep -r "console.log\|winston" src/
```

### Logs Are Huge
**Problem**: Log files taking up space
**Causes**: No log rotation, high volume
**Solutions**:
```bash
# Check log size
docker exec <container-id> du -sh /var/log/

# Enable log rotation (in docker-compose.yml)
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

# Clean old logs
docker logs <container-id> --since 1h > recent-logs.txt

# Use external logging
# Ship logs to: ELK, Splunk, DataDog, etc.
```

## Security Issues

### Security Scanning Vulnerabilities
**Problem**: High-severity CVEs found in scan
**Causes**: Outdated base image, vulnerable dependencies
**Solutions**:
```bash
# Update base image
FROM node:18.17.1-alpine  # Use latest patch

# Update dependencies
npm update
npm audit fix

# Re-scan
trivy image docker-best-practices-app:latest

# Use verified base images
# Check: https://hub.docker.com/_/node/
```

### Container Running as Root
**Problem**: Security scan fails
**Causes**: Missing USER instruction
**Solutions**:
```dockerfile
# Add in Dockerfile
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs

# Verify
docker run docker-best-practices-app:latest id
# Output: uid=1001(nodejs) gid=1001(nodejs)
```

### Secrets Exposed in Image
**Problem**: Found secrets in image
**Causes**: Hardcoded secrets, not using multi-stage
**Solutions**:
```bash
# Scan for secrets
docker scan docker-best-practices-app:latest

# Check image layers
docker history docker-best-practices-app:latest

# Use secrets properly
# NOT: ENV API_KEY=secret
# YES: kubectl create secret generic api-key --from-literal=...
```

## Performance Issues

### Build Takes Too Long
**Problem**: Docker build >10 minutes
**Causes**: No cache, large context, slow network
**Solutions**:
```bash
# Use BuildKit for better caching
DOCKER_BUILDKIT=1 docker build .

# Optimize Dockerfile
# 1. Move system deps up (cache longer)
# 2. Copy package.json before src (cache longer)
# 3. Use .dockerignore (smaller context)

# Check layer sizes
docker history docker-best-practices-app:latest

# Parallel builds (if using compose)
docker-compose build --parallel
```

### App Slow to Start
**Problem**: Takes >30 seconds to respond
**Causes**: Health checks too aggressive, app slow
**Solutions**:
```bash
# Increase probe delays
HEALTHCHECK --start-period=60s ...

# In K8s:
initialDelaySeconds: 60
periodSeconds: 10

# Profile startup
time node src/server.js

# Check dependencies
npm ls --depth=0
```

### Runtime Performance
**Problem**: App using lots of memory/CPU
**Causes**: Resource leak, busy loop, large operations
**Solutions**:
```bash
# Monitor
docker stats

# Profile
node --prof src/server.js
node --prof-process isolate-*.log > processed.txt

# Use monitoring tool
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  google/cadvisor:latest
```

## General Debugging Tips

### Enable Verbose Logging
```bash
# Docker
DOCKER_BUILDKIT=1 docker build --progress=plain .

# Docker Compose
docker-compose --verbose up

# Kubernetes
kubectl -v=4 get pods
```

### Check System Resources
```bash
# Docker disk usage
docker system df

# Docker daemon status
docker info

# System resources
docker stats
free -h  # Linux
```

### Clean Everything
```bash
# WARNING: This removes all unused images/containers/networks
docker system prune -a --volumes

# Restart Docker daemon
# macOS: Docker menu > Restart
# Linux: sudo systemctl restart docker
# Windows: Docker menu > Settings > Reset Docker Engine
```

### Get Help
```bash
# Docker documentation
docker help <command>

# Kubernetes documentation
kubectl explain <resource>

# View man pages
man docker-run
kubectl explain deployment
```

## When All Else Fails

1. **Check logs**: `docker logs`, `kubectl logs`
2. **Check status**: `docker ps`, `kubectl get pods`
3. **Check connectivity**: `curl`, `wget`, `nc`
4. **Check resources**: `docker stats`, `kubectl top`
5. **Search issues**: Stack Overflow, GitHub Issues
6. **Ask community**: Docker Slack, Kubernetes Slack
7. **File issue**: Include logs, config, versions
