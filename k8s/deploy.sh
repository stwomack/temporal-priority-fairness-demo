#!/bin/bash
# Deployment script for Kubernetes
# Usage: ./deploy.sh [namespace] [backend-image] [frontend-image]

set -e

NAMESPACE=${1:-temporal-priority-demo}
BACKEND_IMAGE=${2:-priority-backend:latest}
FRONTEND_IMAGE=${3:-priority-frontend:latest}

echo "Deploying to namespace: $NAMESPACE"
echo "Backend image: $BACKEND_IMAGE"
echo "Frontend image: $FRONTEND_IMAGE"

# Update image references in deployment files
sed -i.bak "s|image: priority-backend:latest|image: $BACKEND_IMAGE|g" deployment-backend.yaml
sed -i.bak "s|image: priority-frontend:latest|image: $FRONTEND_IMAGE|g" deployment-frontend.yaml

# Apply resources
echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Creating ConfigMap..."
kubectl apply -f configmap-backend.yaml

echo "Creating ServiceAccount..."
kubectl apply -f serviceaccount.yaml

echo "Deploying backend..."
kubectl apply -f deployment-backend.yaml
kubectl apply -f service-backend.yaml

echo "Deploying frontend..."
kubectl apply -f deployment-frontend.yaml
kubectl apply -f service-frontend.yaml

echo "Deployment complete!"
echo ""
echo "To check status:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get svc -n $NAMESPACE"
echo ""
echo "To get the LoadBalancer external IP:"
echo "  kubectl get svc priority-frontend -n $NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/priority-backend -n $NAMESPACE"
echo "  kubectl logs -f deployment/priority-frontend -n $NAMESPACE"

# Restore original files
mv deployment-backend.yaml.bak deployment-backend.yaml 2>/dev/null || true
mv deployment-frontend.yaml.bak deployment-frontend.yaml 2>/dev/null || true

