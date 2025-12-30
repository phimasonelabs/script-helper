# CI/CD Infrastructure

This directory installs:
- ArgoCD
- GitHub Actions self-hosted runners (Kubernetes)
- Harbor CA trust for private registry access

## Prerequisites
- Kubernetes cluster
- Harbor already installed
- Harbor Root CA available (`ca.crt`)
- kubectl, helm

## Installation

```bash
./00-prereqs-check.sh
./01-install-argocd.sh
./02-install-actions-runner.sh