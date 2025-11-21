# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the Temporal Priority/Fairness Demo application.

For complete deployment instructions, see [K8s.md](../K8s.md) in the root directory.

## Files in this directory

- **Core manifests**: `namespace.yaml`, `configmap-backend.yaml`, `serviceaccount.yaml`, `deployment-*.yaml`, `service-*.yaml` (frontend uses LoadBalancer)
- **Optional**: `secret-temporal-template.yaml`
- **Utilities**: `nginx.conf` (used by frontend Dockerfile), `deploy.sh` (deployment helper script)

