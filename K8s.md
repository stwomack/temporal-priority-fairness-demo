# Kubernetes Deployment Guide

This guide covers deploying the Temporal Priority/Fairness Demo application to Kubernetes.

> **Note**: Kubernetes deployment is optional. For local development, see the main [README.md](README.md).

## Prerequisites

1. **Kubernetes cluster** (v1.24+)
2. **kubectl** configured to access your cluster
3. **Container registry** (Docker Hub or AWS ECR)
4. **Temporal cluster** (local dev server or Temporal Cloud)

## Quick Start

### 1. Build and Push Docker Images

```bash
# Build backend image
docker build -f Dockerfile.backend -t <your-registry>/priority-backend:latest .

# Build frontend image
docker build -f Dockerfile.frontend -t <your-registry>/priority-frontend:latest .

# Push images
docker push <your-registry>/priority-backend:latest
docker push <your-registry>/priority-frontend:latest
```

**Registry-specific image naming:**

- **Docker Hub**: `docker.io/<username>/priority-backend:latest` or just `<username>/priority-backend:latest`
  - **Important**: You need separate repositories for backend and frontend
  - Create both repositories on Docker Hub first:
    1. Go to https://hub.docker.com/repositories
    2. Create repository named `priority-backend`
    3. Create repository named `priority-frontend`
  - Example: If your username is `myuser`, use:
    - `myuser/priority-backend:latest`
    - `myuser/priority-frontend:latest`
  - Free accounts can create unlimited public repos; private repos require a paid plan
  
- **AWS ECR**: `<account-id>.dkr.ecr.<region>.amazonaws.com/priority-backend:latest`
  - Repository must be created first: `aws ecr create-repository --repository-name priority-backend`
  - Authenticate: `aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com`

**Troubleshooting push errors:**

If you get "push access denied" or "insufficient_scope" errors:

1. **Verify you're logged in**: `docker login` (for Docker Hub) or `docker login <registry-url>`
2. **Check image name format**: Ensure it matches your registry's requirements
   - **Docker Hub**: Use format `<username>/<repository-name>:<tag>` (no nested paths)
   - Example: `myuser/priority-backend:latest` ✅ (correct)
   - Example: `myuser/priority-demo/priority-backend:latest` ❌ (incorrect - too many path segments)
3. **Repository must exist**: For Docker Hub, create both `priority-backend` and `priority-frontend` repositories on hub.docker.com first
4. **Check permissions**: Ensure your account has push permissions to the repository
5. **For Docker Hub**: Use your username, not email: `docker.io/<username>/priority-backend:latest`

### 2. Update Image References

Update the image references in:
- `k8s/deployment-backend.yaml` (line with `image: priority-backend:latest`)
- `k8s/deployment-frontend.yaml` (line with `image: priority-frontend:latest`)

Replace with your actual registry path, e.g.:
- **Docker Hub**: `docker.io/username/priority-backend:latest` or `username/priority-backend:latest`
- **AWS ECR**: `123456789012.dkr.ecr.us-west-2.amazonaws.com/priority-backend:latest`

**Note for Docker Hub**: Make sure you've created separate repositories named `priority-backend` and `priority-frontend` on Docker Hub before pushing.

### 3. Configure Temporal Connection

#### For Local Temporal Dev Server:

Update `k8s/deployment-backend.yaml`:
```yaml
env:
- name: TEMPORAL_NAMESPACE
  value: "default"
- name: TEMPORAL_ADDRESS
  value: "temporal-frontend:7233"  # If Temporal is in same cluster
  # Or external address:
  # value: "temporal.example.com:7233"
```

#### For Temporal Cloud:

1. Create the mTLS secret:
```bash
kubectl create secret generic temporal-mtls \
  --from-file=temporal-client.key=/path/to/temporal-client.key \
  --from-file=temporal-client-cert.pem=/path/to/temporal-client-leaf-cert.pem \
  --namespace=temporal-priority-demo
```

2. Update `k8s/deployment-backend.yaml`:
   - Uncomment the `TEMPORAL_KEY_PATH` and `TEMPORAL_CERT_PATH` environment variables
   - Uncomment the `volumeMounts` section for temporal-certs
   - Uncomment the `volumes` section for temporal-certs
   - Set `TEMPORAL_ADDRESS` to your Temporal Cloud address (e.g., `namespace.tmprl.cloud:7233`)
   - Set `TEMPORAL_NAMESPACE` to your Temporal Cloud namespace

### 4. Configure CORS (if needed)

If your frontend will be served from a different domain, update the `allowed-origins` in `k8s/configmap-backend.yaml`:
```yaml
allowed-origins:
  - "https://your-domain.com"
```

### 5. Deploy to Kubernetes

Deploy resources in order:

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create ConfigMap
kubectl apply -f k8s/configmap-backend.yaml

# Create ServiceAccount
kubectl apply -f k8s/serviceaccount.yaml

# Create Temporal mTLS secret (if using Temporal Cloud)
# kubectl apply -f k8s/secret-temporal.yaml

# Deploy backend
kubectl apply -f k8s/deployment-backend.yaml
kubectl apply -f k8s/service-backend.yaml

# Deploy frontend
kubectl apply -f k8s/deployment-frontend.yaml
kubectl apply -f k8s/service-frontend.yaml
```

Or apply all at once:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap-backend.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment-backend.yaml
kubectl apply -f k8s/service-backend.yaml
kubectl apply -f k8s/deployment-frontend.yaml
kubectl apply -f k8s/service-frontend.yaml
```

Or use the deployment script:
```bash
./k8s/deploy.sh temporal-priority-demo <backend-image> <frontend-image>
```


### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n temporal-priority-demo

# Check services (frontend will have an EXTERNAL-IP when LoadBalancer is ready)
kubectl get svc -n temporal-priority-demo

# View backend logs
kubectl logs -f deployment/priority-backend -n temporal-priority-demo

# View frontend logs
kubectl logs -f deployment/priority-frontend -n temporal-priority-demo
```

### 7. Access the Application

- **Via LoadBalancer**: The frontend service uses LoadBalancer type. Get the external IP:
  ```bash
  kubectl get svc priority-frontend -n temporal-priority-demo
  ```
  Access the application at `http://<EXTERNAL-IP>`. The frontend nginx configuration automatically proxies `/api` requests to the backend.

- **Via Port Forward** (for testing or if LoadBalancer isn't available):
  ```bash
  # Frontend
  kubectl port-forward svc/priority-frontend 4000:80 -n temporal-priority-demo
  # Then access at http://localhost:4000
  
  # Backend (direct)
  kubectl port-forward svc/priority-backend 7080:7080 -n temporal-priority-demo
  ```

## Configuration Files

All Kubernetes manifests are located in the `k8s/` directory.

### Required Files

- `k8s/namespace.yaml` - Kubernetes namespace
- `k8s/configmap-backend.yaml` - Application configuration
- `k8s/serviceaccount.yaml` - Service account for backend
- `k8s/deployment-backend.yaml` - Backend deployment
- `k8s/service-backend.yaml` - Backend service
- `k8s/deployment-frontend.yaml` - Frontend deployment
- `k8s/service-frontend.yaml` - Frontend service

### Optional Files

- `k8s/secret-temporal-template.yaml` - Template for Temporal Cloud mTLS
- `k8s/deploy.sh` - Deployment helper script

## Environment Variables

### Backend Deployment

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `TEMPORAL_NAMESPACE` | Temporal namespace | Yes | `default` |
| `TEMPORAL_ADDRESS` | Temporal server address | Yes | `127.0.0.1:7233` |
| `TEMPORAL_KEY_PATH` | Path to Temporal mTLS key (Cloud) | No* | - |
| `TEMPORAL_CERT_PATH` | Path to Temporal mTLS cert (Cloud) | No* | - |

*Required for Temporal Cloud

## Resource Requirements

### Backend
- **Requests**: 512Mi memory, 500m CPU
- **Limits**: 1Gi memory, 1000m CPU
- **Replicas**: 2 (minimum)

### Frontend
- **Requests**: 64Mi memory, 100m CPU
- **Limits**: 128Mi memory, 200m CPU
- **Replicas**: 2 (minimum)

## Scaling

The deployments are configured with 2 replicas by default. To scale manually, update the `replicas` field in the deployment files or use:

```bash
kubectl scale deployment/priority-backend --replicas=<number> -n temporal-priority-demo
kubectl scale deployment/priority-frontend --replicas=<number> -n temporal-priority-demo
```

## Monitoring

### Health Checks

- **Backend**: `/actuator/health/liveness` and `/actuator/health/readiness`
- **Frontend**: `/` (root path)

### Metrics

Backend exposes Prometheus metrics at `/actuator/prometheus` if you want to set up monitoring separately.

## Troubleshooting

### Backend not connecting to Temporal

1. Verify `TEMPORAL_ADDRESS` and `TEMPORAL_NAMESPACE` are correct
2. Check network connectivity from pods to Temporal server
3. For Temporal Cloud, verify mTLS certificates are mounted correctly
4. Check backend logs: `kubectl logs deployment/priority-backend -n temporal-priority-demo`

### Frontend can't reach backend

1. Verify backend service is running: `kubectl get svc priority-backend -n temporal-priority-demo`
2. Check nginx configuration in frontend pod
3. Verify CORS settings in backend ConfigMap
4. Check frontend logs: `kubectl logs deployment/priority-frontend -n temporal-priority-demo`

### Pods not starting

1. Check pod status: `kubectl describe pod <pod-name> -n temporal-priority-demo`
2. Check events: `kubectl get events -n temporal-priority-demo --sort-by='.lastTimestamp'`
3. Verify image pull secrets if using private registry
4. Check resource limits aren't too restrictive

## Security Considerations

1. **Secrets**: Never commit actual secrets. Use Kubernetes Secrets or a secret management solution
2. **Network Policies**: Consider adding NetworkPolicies to restrict pod-to-pod communication
3. **RBAC**: The ServiceAccount has minimal permissions. Adjust as needed
4. **TLS**: For production, consider using an Ingress with TLS or AWS ALB with SSL certificates
5. **Image Security**: Use image scanning and signed images in production

## Updating the Deployment

### Update Application Code

1. Build new Docker images with updated tags
2. Push to registry
3. Update image tags in deployment files
4. Apply: `kubectl apply -f k8s/deployment-backend.yaml` (or frontend)

### Rolling Update

Kubernetes will perform a rolling update automatically when you update the deployment. Monitor with:
```bash
kubectl rollout status deployment/priority-backend -n temporal-priority-demo
```

### Rollback

If something goes wrong:
```bash
kubectl rollout undo deployment/priority-backend -n temporal-priority-demo
```

## Production Recommendations

1. **Use specific image tags** instead of `latest`
2. **Enable TLS** (consider using Ingress with TLS or AWS ALB)
3. **Configure resource limits** appropriately
4. **Set up monitoring and alerting** (Prometheus, Grafana)
5. **Use a proper secret management solution** (Vault, External Secrets Operator)
6. **Enable pod disruption budgets** for high availability
7. **Configure backup strategies** for any persistent data
8. **Set up CI/CD pipelines** for automated deployments
9. **Use GitOps** (ArgoCD, Flux) for declarative deployments
10. **Review and adjust security contexts** based on your security policies

