# Kubernetes Deployment Guide

## Prerequisites
- Kubernetes cluster (1.20+)
- kubectl configured
- Docker image pushed to registry

## Quick Deploy

```bash
# Create all resources
kubectl apply -f k8s/

# Verify deployment
kubectl get all -n docker-best-practices

# Check pod status
kubectl get pods -n docker-best-practices -w

# View logs
kubectl logs -n docker-best-practices -l app=docker-best-practices-app -f
```

## Deployment Components

### 1. Namespace
Isolates resources from other applications
```bash
kubectl get namespace docker-best-practices
```

### 2. ConfigMap
Non-sensitive configuration (NODE_ENV, PORT)
```bash
kubectl get configmap -n docker-best-practices
kubectl describe cm app-config -n docker-best-practices
```

### 3. Secret
Sensitive data (database passwords, API keys)
```bash
kubectl get secret -n docker-best-practices
# Never output secrets with -o yaml!
```

### 4. Deployment
Manages pod replicas with rolling updates
```bash
kubectl get deployment -n docker-best-practices -w
kubectl rollout status deployment/app -n docker-best-practices
```

### 5. Service
Internal load balancing (ClusterIP)
```bash
kubectl get svc -n docker-best-practices
# Test internal connectivity
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  wget -O- http://app-service.docker-best-practices.svc.cluster.local
```

### 6. HorizontalPodAutoscaler
Scales pods based on CPU/memory
```bash
kubectl get hpa -n docker-best-practices
kubectl describe hpa app-hpa -n docker-best-practices
```

### 7. NetworkPolicy
Restricts traffic between pods
```bash
kubectl get networkpolicy -n docker-best-practices
```

### 8. RBAC Resources
Least-privilege access control
```bash
kubectl get sa,role,rolebinding -n docker-best-practices
```

### 9. PodDisruptionBudget
Ensures availability during disruptions
```bash
kubectl get pdb -n docker-best-practices
```

## Scaling Strategies

### Manual Scaling
```bash
# Scale to 5 replicas
kubectl scale deployment app -n docker-best-practices --replicas=5

# View new pods
kubectl get pods -n docker-best-practices
```

### Automatic Scaling (HPA)
```bash
# View HPA status
kubectl get hpa -n docker-best-practices -w

# Check metrics
kubectl get hpa app-hpa -n docker-best-practices -o wide

# Describe for details
kubectl describe hpa app-hpa -n docker-best-practices
```

Current configuration:
- Minimum replicas: 3
- Maximum replicas: 10
- CPU target: 70%
- Memory target: 80%

## Rolling Updates

### Update Image
```bash
# Set new image
kubectl set image deployment/app \
  app=myregistry/docker-best-practices-app:2.0.0 \
  -n docker-best-practices

# Watch rollout
kubectl rollout status deployment/app -n docker-best-practices -w

# Check pods
kubectl get pods -n docker-best-practices
```

### Rollback if Issues
```bash
# View rollout history
kubectl rollout history deployment/app -n docker-best-practices

# Rollback to previous
kubectl rollout undo deployment/app -n docker-best-practices

# Rollback to specific revision
kubectl rollout undo deployment/app --to-revision=1 \
  -n docker-best-practices
```

## Monitoring Health

### Pod Status
```bash
# Check all pods
kubectl get pods -n docker-best-practices

# Detailed pod info
kubectl describe pod <pod-name> -n docker-best-practices

# Check events
kubectl get events -n docker-best-practices --sort-by='.lastTimestamp'
```

### Probe Status
```bash
# Check liveness probe failures
kubectl logs <pod-name> -n docker-best-practices | grep -i "kill\|restart"

# Check readiness probe
kubectl describe pod <pod-name> -n docker-best-practices | grep -A 10 "Conditions"
```

### Resource Usage
```bash
# View resource metrics
kubectl top pods -n docker-best-practices

# Node metrics
kubectl top nodes

# Watch resource usage
watch kubectl top pods -n docker-best-practices
```

## Debugging

### Interactive Shell
```bash
# Connect to running container
kubectl exec -it <pod-name> -n docker-best-practices -- sh

# View process
ps aux
# View files
ls -la
# Test connectivity
curl http://localhost:3000/health
```

### Logs
```bash
# View pod logs
kubectl logs <pod-name> -n docker-best-practices

# Follow logs (tail -f)
kubectl logs -f <pod-name> -n docker-best-practices

# Previous container logs (if crashed)
kubectl logs <pod-name> --previous -n docker-best-practices

# All replicas
kubectl logs -l app=docker-best-practices-app -n docker-best-practices -f
```

### Port Forward
```bash
# Access pod directly
kubectl port-forward <pod-name> 3000:3000 -n docker-best-practices

# Access service
kubectl port-forward svc/app-service 3000:80 -n docker-best-practices

# From another terminal
curl http://localhost:3000/health
```

## Ingress Setup (Optional)

### Prerequisites
```bash
# Install nginx-ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### Update DNS
```bash
# Get ingress IP
kubectl get ingress -n docker-best-practices

# Add to DNS:
# app.example.com A <IP>
```

### Test
```bash
# Health check
curl http://app.example.com/health

# Info
curl http://app.example.com/api/info
```

## Secret Management

### Create Secrets
```bash
# From literal values
kubectl create secret generic app-secrets \
  --from-literal=DATABASE_URL="postgres://..." \
  --from-literal=API_KEY="sk_..." \
  -n docker-best-practices

# From file
kubectl create secret generic app-secrets \
  --from-file=secrets.env \
  -n docker-best-practices
```

### View Secrets (Safely)
```bash
# List secrets
kubectl get secrets -n docker-best-practices

# View secret keys
kubectl describe secret app-secrets -n docker-best-practices

# Never do: kubectl get secret -o yaml
```

### Update Secrets
```bash
# Delete and recreate
kubectl delete secret app-secrets -n docker-best-practices
kubectl create secret generic app-secrets \
  --from-literal=DATABASE_URL="postgres://..." \
  -n docker-best-practices

# Rollout pods to pick up new secret
kubectl rollout restart deployment/app -n docker-best-practices
```

## Network Policy Testing

### Verify Policies
```bash
# View network policies
kubectl get networkpolicy -n docker-best-practices

# Describe policy
kubectl describe networkpolicy app-network-policy \
  -n docker-best-practices
```

### Test Connectivity
```bash
# Create debug pod
kubectl run -it --rm debug \
  --image=alpine \
  --restart=Never \
  -n docker-best-practices \
  -- sh

# From debug pod:
# Successful - allowed
wget -O- http://app-service:80

# Should fail - denied by network policy
wget -O- http://app-service:80 --timeout=2

# Check DNS
nslookup app-service
```

## Quota and Limits

### Namespace Quota
```bash
# Create ResourceQuota (optional)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-quota
  namespace: docker-best-practices
spec:
  hard:
    requests.cpu: "5"
    requests.memory: "5Gi"
    limits.cpu: "10"
    limits.memory: "10Gi"
    pods: "20"
EOF
```

### View Quota Usage
```bash
kubectl describe resourcequota app-quota -n docker-best-practices
```

## Backup and Restore

### Backup Deployment
```bash
# Export deployment
kubectl get deployment app -n docker-best-practices -o yaml > app-backup.yaml

# Export all resources
kubectl get all -n docker-best-practices -o yaml > full-backup.yaml
```

### Restore Deployment
```bash
# Restore from backup
kubectl apply -f app-backup.yaml
```

## Production Checklist

- [ ] Image pushed to registry
- [ ] Secrets created in K8s
- [ ] Resource limits configured
- [ ] Health probes working
- [ ] Rolling update strategy tested
- [ ] Rollback procedure documented
- [ ] Network policies applied
- [ ] Monitoring/alerts configured
- [ ] Backup strategy in place
- [ ] Disaster recovery tested

## Common Issues

### Pods not starting
```bash
kubectl describe pod <pod-name> -n docker-best-practices
# Check "Events" section for error details
```

### CrashLoopBackOff
```bash
# View logs
kubectl logs <pod-name> -n docker-best-practices --previous

# Check readiness probe
# Might be failing too early (increase initialDelaySeconds)
```

### Readiness probe failing
```bash
# Check if endpoint is accessible
kubectl exec -it <pod-name> -n docker-best-practices -- \
  wget -O- http://localhost:3000/ready
```

### High memory usage
```bash
# Check memory metrics
kubectl top pod <pod-name> -n docker-best-practices

# Increase limits if legitimate
kubectl set resources deployment app \
  --limits=memory=1Gi \
  -n docker-best-practices
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Deployment Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Probes Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
