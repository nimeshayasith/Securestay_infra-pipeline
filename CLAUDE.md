# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository owns **all AWS infrastructure** for the SecureStay hotel booking platform. Everything is declared in Terraform and deployed through GitHub Actions — nothing is created manually in the AWS Console.

- **Cloud:** AWS (us-east-1)
- **IaC:** Terraform 1.7.5 with modules pattern, remote S3 backend
- **Compute:** AWS EKS (Kubernetes)
- **CI/CD:** GitHub Actions

**Current state:** The repository is in scaffolding phase. [CLAUDE_INFRA.md](CLAUDE_INFRA.md) is the authoritative implementation guide — read it before making any changes.

---

## Common Commands

All main infrastructure commands run from `environments/prod/`:

```bash
# Bootstrap (one-time manual step — creates S3 state bucket + DynamoDB lock table)
cd bootstrap/ && terraform init && terraform apply -auto-approve

# Plan/apply main infrastructure
cd environments/prod/
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -no-color -out=tfplan
terraform apply -auto-approve -input=false

# Read outputs after apply
terraform output -raw rds_endpoint
terraform output ecr_repository_urls
```

Database migrations (run after first apply):
```bash
PGPASSWORD=$TF_VAR_db_password psql \
  -h <rds-endpoint> -U securestay_admin -d securestay \
  -f modules/database/schema.sql
```

---

## Repository Structure (Target State)

```
Securestay_infra-pipeline/
├── bootstrap/              # Run ONCE manually — S3 bucket + DynamoDB for Terraform state
├── modules/
│   ├── network/            # VPC (10.0.0.0/16), multi-AZ public/private subnets, IGW, NAT GWs
│   ├── iam/                # EKS cluster/node roles + 4 team IAM users (1 admin, 3 read-only)
│   ├── ecr/                # 5 ECR repos (api-gateway, auth, booking, payment, notification)
│   ├── database/           # Single shared RDS PostgreSQL + schema.sql
│   ├── compute/            # EKS cluster (2–4 × t3.medium nodes, 2 AZs) + add-ons
│   ├── rabbitmq/           # RabbitMQ Helm release (3 replicas, internal NLB only)
│   ├── storage/            # S3 buckets (app assets, logs)
│   └── dns/                # Route 53 A record → application ALB
├── environments/
│   └── prod/               # Root module: wires all submodules together
├── helm/
│   └── rabbitmq-values.yaml
├── scripts/
│   ├── bootstrap.sh        # Runner for bootstrap/ (one-time)
│   └── run-migrations.sh   # Applies schema.sql to RDS
└── .github/
    └── workflows/
        ├── infra-plan.yml  # PR gate: fmt/validate/plan → post as PR comment
        └── infra-apply.yml # On merge: apply + install LB Controller + NGINX Ingress
```

---

## Architecture Decisions

### Database: Single Shared RDS PostgreSQL

All four microservices share **one** RDS PostgreSQL instance (`securestay` database). There is **no in-cluster database of any kind**.

| Service | Tables |
|---|---|
| `auth-service` | `users` |
| `booking-service` | `hotels`, `rooms`, `bookings` |
| `payment-service` | `payments` |
| `notification-service` | `notification_logs` (replaces MongoDB) |

- `k8s/postgres.yaml` and `k8s/mongodb.yaml` from the app repo are **deleted — never apply them**
- RDS lives in private subnets only; security group restricts port 5432 to EKS worker nodes exclusively
- RabbitMQ is the only messaging infrastructure inside Kubernetes (Helm release, internal NLB)

### Module Wiring

`environments/prod/main.tf` is the root module that calls all submodules and wires outputs. Modules communicate exclusively via strongly-typed `outputs.tf` files. Terraform resolves dependency order automatically; logical order for debugging: `bootstrap → iam → network → storage → ecr → database → compute → rabbitmq → dns`.

### Required GitHub Secrets

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | nimesh-admin IAM credentials |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `TF_VAR_db_password` | PostgreSQL master password (min 16 chars) |
| `TF_VAR_rabbitmq_password` | RabbitMQ admin password |

---

## Conventions

- **Tagging:** Every AWS resource must carry `Project = SecureStay`, `Environment = prod`, `ManagedBy = Terraform`
- **Secrets:** All passwords injected via `TF_VAR_*` GitHub Secrets — never hardcoded
- **Deletion protection:** `prevent_destroy` lifecycle on S3 state bucket, RDS, ECR; `deletion_protection = true` on RDS
- **EKS subnet tags** are required for the AWS Load Balancer Controller to discover subnets:
  - Private: `kubernetes.io/role/internal-elb = 1`
  - Public: `kubernetes.io/role/elb = 1`
  - Both: `kubernetes.io/cluster/securestay-eks = shared`
- **ECR lifecycle:** Keep last 10 images per repository
