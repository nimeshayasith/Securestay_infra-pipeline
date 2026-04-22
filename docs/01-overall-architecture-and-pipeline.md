# Overall Architecture And Pipeline

## 1. Why This Repository Exists

This repository is the infrastructure side of the SecureStay project.

Its job is to create and manage the AWS resources that the application needs in order to run safely and consistently. Instead of clicking around manually in the AWS Console, the infrastructure is written as code using Terraform. That approach is called Infrastructure as Code, or IaC.

For a beginner, the biggest idea to understand is this:

- The application code and the infrastructure code are different responsibilities.
- The application provides the business features.
- The infrastructure provides the environment where the application can run.

This repository focuses on the second part.

## 2. Big Picture Architecture

At a high level, the project creates a cloud platform in AWS with networking, compute, database, storage, messaging, and deployment automation.

You can think about the architecture like this:

```text
Developers
   |
   v
GitHub Repository
   |
   +--> Pull Request -> GitHub Actions -> Terraform Plan
   |
   +--> Merge to main -> GitHub Actions -> Terraform Apply
                                       |
                                       v
                                     AWS
                                       |
     ----------------------------------------------------------------
     |                |                |              |              |
     v                v                v              v              v
    VPC             IAM              EKS            RDS            S3/ECR
     |                |                |              |              |
     |                |                +--> RabbitMQ  |              |
     |                |                +--> Ingress   |              |
     |                |                               |              |
     ---------------------------------------------------------------
                                       |
                                       v
                              SecureStay application platform
```

## 3. Main Components In Simple Language

### 3.1 VPC and Networking

The VPC is the private network space for the project inside AWS. It is like building your own virtual data center.

Inside the VPC, the project creates:

- public subnets
- private subnets
- an Internet Gateway
- NAT Gateways
- route tables

Why this matters:

- Public subnets are used for internet-facing resources.
- Private subnets are used for internal resources like EKS worker nodes and the database.
- NAT Gateways allow private resources to access the internet for updates and package downloads without exposing them directly to the public internet.

### 3.2 IAM

IAM controls identity and permissions.

This project creates:

- an admin user
- read-only users
- an IAM role for the EKS control plane
- an IAM role for the EKS worker nodes

Why this matters:

- People need controlled access to AWS.
- AWS services also need permission to talk to other AWS services.
- EKS cannot operate properly without the correct IAM roles.

### 3.3 EKS

EKS is the managed Kubernetes service in AWS.

This project creates:

- an EKS cluster
- a managed node group
- core EKS add-ons such as CoreDNS, kube-proxy, and VPC CNI

Why this matters:

- Kubernetes is the platform that runs containerized microservices.
- EKS removes some operational burden because AWS manages the control plane.

### 3.4 RDS PostgreSQL

RDS is the managed database service in AWS.

This project creates one PostgreSQL instance for SecureStay.

Why this matters:

- The services need persistent relational data.
- Using RDS is easier and safer than installing PostgreSQL manually on an EC2 instance.

### 3.5 S3

S3 is used for object storage.

This project creates:

- an application assets bucket
- an access logs bucket

Why this matters:

- Applications often need a place to store files such as uploads or static assets.
- Logs are useful for auditing and troubleshooting.

### 3.6 ECR

ECR is AWS's container image registry.

This project creates repositories for:

- `api-gateway`
- `auth-service`
- `booking-service`
- `payment-service`
- `notification-service`

Why this matters:

- Docker images need a secure registry.
- Kubernetes pulls application images from ECR before running the containers.

### 3.7 RabbitMQ

RabbitMQ is used as a message broker.

In this project it is deployed into Kubernetes through Helm.

Why this matters:

- It enables asynchronous communication between services.
- One service can send a message and another service can process it later.

### 3.8 DNS

Route 53 DNS is used to point a friendly domain name to the ingress load balancer.

Why this matters:

- Users prefer a domain such as `app.securestay.com` rather than a raw AWS load balancer URL.

## 4. How The Components Work Together

Here is the infrastructure story in sequence:

1. Terraform creates the VPC and subnets.
2. Terraform creates IAM roles.
3. Terraform creates the EKS cluster inside the VPC.
4. Terraform creates the worker nodes in private subnets.
5. Terraform creates the PostgreSQL database in private subnets.
6. Terraform creates S3 buckets and ECR repositories.
7. Terraform uses Helm to install RabbitMQ into the Kubernetes cluster.
8. GitHub Actions installs ingress-related controllers after infrastructure deployment.
9. DNS can point the application domain to the created load balancer.

This gives you a full cloud platform rather than a single standalone server.

## 5. Repository Structure Explained

This repository follows a modular design.

```text
bootstrap/
  Creates Terraform backend resources

environments/prod/
  Production entrypoint that calls reusable modules

modules/
  Small focused building blocks such as network, compute, database, IAM, storage

helm/
  Helm values used for Kubernetes workloads

.github/workflows/
  CI/CD pipeline for plan and apply

scripts/
  Helper scripts for backend bootstrap and database schema setup
```

This is a good practice because it avoids putting everything in one huge Terraform file.

## 6. Pipeline Overview

The infrastructure pipeline uses GitHub Actions.

There are two main workflows:

- `infra-plan.yml`
- `infra-apply.yml`

### 6.1 Plan Workflow

The plan workflow runs on pull requests to `main`.

Its job is to:

- check Terraform formatting
- initialize Terraform
- validate the configuration
- generate a Terraform plan
- post the plan result to the pull request

Why this is useful:

- Team members can review infrastructure changes before they are applied.
- It reduces surprises.
- It brings code review into infrastructure work.

### 6.2 Apply Workflow

The apply workflow runs on pushes to `main`.

Its job is to:

- initialize Terraform
- apply the infrastructure
- update kubeconfig for the EKS cluster
- install the AWS Load Balancer Controller
- install the NGINX Ingress Controller
- print useful outputs such as RDS endpoint and ECR repository URLs

Why this is useful:

- It automates deployment after approved changes are merged.
- It reduces manual mistakes.
- It makes the platform repeatable.

## 7. End-To-End Pipeline Story

Here is the full beginner-friendly flow:

```text
Developer edits Terraform
        |
        v
Push branch to GitHub
        |
        v
Open Pull Request
        |
        v
GitHub Actions runs terraform fmt, init, validate, plan
        |
        v
Plan is posted to PR for review
        |
        v
PR merged into main
        |
        v
GitHub Actions runs terraform apply
        |
        v
AWS resources are created or updated
        |
        v
Cluster add-ons and controllers are installed
        |
        v
Application platform becomes ready for workloads
```

## 8. Important Secrets And Inputs

The pipeline expects AWS and Terraform secrets in GitHub.

Examples used by this repository:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `TF_VAR_db_password`
- `TF_VAR_rabbitmq_password`

Why this matters:

- Sensitive values should not be stored directly in Terraform files committed to Git.
- GitHub Secrets keeps them out of the codebase.

## 9. Best Practices Used In This Project

This section explains the good practices that were applied here.

### 9.1 Infrastructure As Code

All important infrastructure is written in Terraform instead of being created manually in the AWS Console.

Benefit:

- repeatability
- better review process
- easier recovery
- version history

### 9.2 Modular Terraform Design

The code is split into modules like `network`, `compute`, `database`, and `storage`.

Benefit:

- easier to understand
- easier to test and change
- better reuse

### 9.3 Remote State

Terraform state is stored remotely in S3, and state locking is handled by DynamoDB.

Benefit:

- safer team collaboration
- reduced chance of state corruption
- one shared source of truth

### 9.4 Validation Before Apply

The pipeline runs format checks, validation, and plan before apply.

Benefit:

- catches mistakes earlier
- improves reliability
- supports peer review

### 9.5 Private Database Placement

The RDS instance is deployed in private subnets.

Benefit:

- reduces direct internet exposure
- improves security

### 9.6 Network Segmentation

Public and private subnets are separated.

Benefit:

- clearer security boundaries
- better architecture design

### 9.7 Encryption And Public Access Controls

S3 buckets use server-side encryption and public access blocking.

Benefit:

- protects stored data
- reduces accidental exposure

### 9.8 Container Image Management

ECR repositories use image scanning and lifecycle policies.

Benefit:

- better image hygiene
- reduced storage growth
- better security awareness

### 9.9 Managed Services

This project uses managed AWS services such as EKS, RDS, S3, and ECR.

Benefit:

- less operational burden
- easier maintenance
- better availability compared to self-managed setups

## 10. Practical Learning Lessons

If you are learning from this project, these are the main concepts to understand deeply:

- how Terraform modules connect together
- how a VPC is designed
- why public and private subnets are separated
- how IAM roles allow AWS services to work
- how EKS uses subnets, security groups, and worker nodes
- how RDS is protected inside the VPC
- how GitHub Actions turns infrastructure changes into an automated pipeline
- how secrets are injected safely during CI/CD

## 11. Tradeoffs And Real-World Notes

This project applies several strong practices, but it also includes some learning-focused simplifications.

Examples:

- an admin IAM user is convenient for learning, but in production AWS SSO or short-lived roles are usually better
- a single RDS instance is simpler and cheaper, but not as resilient as a multi-AZ production setup
- RabbitMQ persistence is disabled, which lowers complexity and cost, but reduces durability
- public access to the EKS API endpoint is easier for administration, but private-only access is stricter

These are not "wrong." They are useful stepping stones when learning cloud infrastructure.

## 12. What You Should Learn Next

After understanding this repository, the next important topics are:

- Kubernetes manifests and Helm charts
- application deployment pipelines
- observability with logs and metrics
- secure secret management with AWS Secrets Manager or SSM Parameter Store
- autoscaling and cost optimization
- disaster recovery and backups

## 13. Final Summary

This repository is more than a set of Terraform files. It is a complete learning example of how to build a cloud platform in AWS using modern infrastructure practices.

The key learning outcome is this:

- Terraform defines the infrastructure.
- GitHub Actions automates the changes.
- AWS provides the managed services.
- Kubernetes provides the runtime platform.
- Good architecture and best practices make the system safer, clearer, and easier to manage.
