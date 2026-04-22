# SecureStay Infrastructure Pipeline

This repository contains the Terraform infrastructure and infrastructure CI/CD pipeline for the SecureStay project.

If you are learning cloud infrastructure, start with these two guides:

- [Overall Architecture And Pipeline](docs/01-overall-architecture-and-pipeline.md)
- [AWS Infrastructure Explained](docs/02-aws-infrastructure-explained.md)

## Repository Purpose

This repo is responsible for creating and managing:

- AWS networking
- IAM users and roles
- EKS cluster and worker nodes
- PostgreSQL database on RDS
- S3 buckets
- ECR repositories
- RabbitMQ deployment with Helm
- DNS integration
- Terraform remote state backend
- GitHub Actions pipeline for `terraform plan` and `terraform apply`

## Main Folders

- [`bootstrap`](bootstrap): creates the Terraform backend bucket and lock table
- [`environments/prod`](environments/prod): production environment entrypoint
- [`modules`](modules): reusable Terraform modules
- [`helm`](helm): Helm values used by Kubernetes deployments
- [`.github/workflows`](.github/workflows): infrastructure CI/CD workflows
- [`scripts`](scripts): helper scripts for bootstrap and schema setup

## Typical Flow

1. Bootstrap the backend state storage.
2. Configure the production environment variables and secrets.
3. Open a pull request to trigger `terraform plan`.
4. Merge to `main` to trigger `terraform apply`.
5. Use the Terraform outputs for application integration.

## Learning Goal

The documents in `docs/` explain not only what was built, but also why each part exists, how the pieces connect together, and which best practices were used in the project.
