# Infrastructure Pipeline Beginner Guide

## 1. Purpose Of This Document

This document explains the SecureStay infrastructure pipeline in beginner-friendly DevOps language.

It answers these questions:

- What is an infrastructure pipeline?
- What does this project's infrastructure pipeline do?
- What is the correct order of execution?
- Why do we use this pipeline?
- Why is each step important?
- What are the best practices used in this project?

## 2. What Is An Infrastructure Pipeline?

An infrastructure pipeline is an automated process that creates, updates, validates, or destroys cloud infrastructure.

In this project, the infrastructure pipeline uses:

- GitHub Actions as the automation tool
- Terraform as the Infrastructure as Code tool
- AWS as the cloud provider
- Kubernetes tools such as `kubectl` and Helm after EKS is created

Instead of manually creating resources in the AWS Console, the team writes Terraform code. Then GitHub Actions runs that Terraform code in a controlled way.

Simple idea:

```text
Terraform code in GitHub
  |
  v
GitHub Actions workflow
  |
  v
Terraform plan/apply/destroy
  |
  v
AWS infrastructure
```

## 3. Why Do We Use An Infrastructure Pipeline?

Without a pipeline, a developer may manually create AWS resources from the AWS Console.

That approach is risky because:

- people can forget steps
- resources may be created differently each time
- it is hard to review changes before they happen
- it is hard to know who changed what
- it is hard to recreate the same environment after `terraform destroy`

With an infrastructure pipeline:

- the infrastructure is created from code
- changes are reviewed before applying
- the same steps run every time
- secrets stay in GitHub Secrets instead of local files
- the team can destroy and recreate the environment more safely
- the project becomes easier to demonstrate and explain

## 4. Infrastructure Pipeline Files In This Project

The infrastructure workflows are inside:

```text
.github/workflows/
```

The important files are:

| Workflow File | Purpose |
| --- | --- |
| `infra-plan.yml` | Checks Terraform formatting, validates code, and shows what Terraform will change |
| `infra-apply.yml` | Creates or updates AWS infrastructure and prepares EKS ingress |
| `infra-destroy.yml` | Destroys production infrastructure only after manual confirmation |

The Terraform production environment is inside:

```text
environments/prod/
```

Reusable Terraform modules are inside:

```text
modules/
```

## 5. Big Picture Pipeline Order

The safest order is:

```text
1. Developer changes Terraform code
2. Infrastructure Plan workflow runs
3. Team reviews the Terraform plan
4. Infrastructure Apply workflow runs
5. Terraform creates or updates AWS resources
6. Workflow connects to EKS
7. Workflow checks Kubernetes system health
8. Workflow installs or verifies ingress
9. Workflow prints important outputs for the app pipeline
10. Application pipeline deploys the application
```

For destroy:

```text
1. User manually starts Infrastructure Destroy workflow
2. User types DESTROY to confirm
3. Workflow shows destroy plan
4. Workflow removes Kubernetes add-ons where possible
5. Terraform destroys AWS infrastructure
```

## 6. Infrastructure Plan Workflow

### What It Does

The plan workflow is defined in:

```text
.github/workflows/infra-plan.yml
```

It runs when:

- someone opens or updates a pull request to `main`
- someone manually starts the workflow

It only runs when infrastructure-related files change:

```text
.github/workflows/**
environments/**
modules/**
helm/**
```

### Why It Is Used

The plan workflow is used to preview infrastructure changes before they are applied to AWS.

It answers:

```text
What will Terraform create?
What will Terraform update?
What will Terraform delete?
Is the Terraform code valid?
```

### Step Order

| Order | Step | What It Means |
| --- | --- | --- |
| 1 | Checkout code | GitHub Actions downloads the repository code |
| 2 | Configure AWS credentials | Workflow gets permission to talk to AWS |
| 3 | Setup Terraform | Installs Terraform version `1.7.5` |
| 4 | Format check | Checks whether Terraform files are properly formatted |
| 5 | Terraform init | Connects Terraform to providers and remote backend |
| 6 | Terraform validate | Checks Terraform syntax and configuration |
| 7 | Terraform plan | Creates a preview of infrastructure changes |
| 8 | Render plan output | Converts the plan into readable text |
| 9 | Post plan to PR | Adds or updates a GitHub pull request comment |
| 10 | Fail if plan failed | Stops the workflow if Terraform plan failed |

### Important Commands

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -no-color -out=tfplan
terraform show -no-color tfplan
```

### Why Each Command Matters

| Command | Importance |
| --- | --- |
| `terraform fmt -check -recursive` | Keeps Terraform code style consistent |
| `terraform init` | Downloads providers and connects to backend state |
| `terraform validate` | Finds syntax/configuration errors early |
| `terraform plan` | Shows expected AWS changes before applying |
| `terraform show` | Converts the saved plan into readable output |

### Best Practices Used

- Plan runs before apply.
- Plan output is posted to the pull request.
- Terraform version is pinned.
- AWS region has a fallback to `us-east-1`.
- Secrets are passed through GitHub Secrets.
- Concurrency cancels old plan runs for the same PR.

## 7. Infrastructure Apply Workflow

### What It Does

The apply workflow is defined in:

```text
.github/workflows/infra-apply.yml
```

It runs when:

- changes are pushed to `main`
- someone manually starts the workflow

This workflow actually creates or updates AWS resources.

### Why It Is Used

The apply workflow is used to make the real cloud infrastructure match the Terraform code.

It creates and manages:

- VPC
- public subnets
- private subnets
- internet gateway
- NAT gateways
- route tables
- IAM roles
- ECR repositories
- S3 buckets
- RDS PostgreSQL
- EKS cluster
- EKS worker nodes
- EKS add-ons
- RabbitMQ through Helm
- DNS records when configured
- NGINX ingress controller after EKS is ready

### Step Order

| Order | Step | What It Means |
| --- | --- | --- |
| 1 | Checkout code | Downloads repository code |
| 2 | Configure AWS credentials | Allows workflow to create AWS resources |
| 3 | Setup Terraform | Installs Terraform `1.7.5` |
| 4 | Setup Helm | Installs Helm for Kubernetes chart deployment |
| 5 | Setup kubectl | Installs Kubernetes CLI |
| 6 | Terraform init | Connects Terraform to backend and providers |
| 7 | Terraform apply | Creates or updates AWS infrastructure |
| 8 | Update kubeconfig | Connects `kubectl` to the EKS cluster |
| 9 | Wait for EKS nodes and add-ons | Confirms Kubernetes is ready |
| 10 | Check AWS Load Balancer Controller service account | Decides whether ALB controller can be installed |
| 11 | Install or skip AWS Load Balancer Controller | Handles controller safely |
| 12 | Clean failed NGINX ingress release | Removes only failed ingress release state |
| 13 | Install NGINX ingress controller | Creates ingress controller and LoadBalancer service |
| 14 | Wait for ingress rollout | Confirms NGINX controller pod is ready |
| 15 | Wait for ingress service | Confirms Kubernetes Service exists |
| 16 | Wait for load balancer endpoint | Confirms AWS assigned public endpoint |
| 17 | Print RDS endpoint | Gives database endpoint for app pipeline |
| 18 | Print ECR repository URLs | Gives image repository URLs for app pipeline |

### Important Commands

```bash
terraform init
terraform apply -auto-approve -input=false
aws eks update-kubeconfig --region us-east-1 --name securestay-eks
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl rollout status deployment/coredns -n kube-system --timeout=10m
kubectl rollout status daemonset/aws-node -n kube-system --timeout=10m
kubectl rollout status daemonset/kube-proxy -n kube-system --timeout=10m
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx
terraform output -raw rds_endpoint
terraform output ecr_repository_urls
```

### Why Terraform Apply Comes Before Kubectl

`kubectl` can only connect to Kubernetes after EKS exists.

That is why the order is:

```text
Terraform apply creates EKS
  |
  v
aws eks update-kubeconfig connects kubectl to EKS
  |
  v
kubectl and Helm install/check Kubernetes resources
```

If this order is reversed, `kubectl` has no cluster to connect to.

### Why EKS Readiness Checks Are Important

After AWS creates EKS, Kubernetes may still need time before it is usable.

The workflow checks:

- EKS nodes are Ready
- CoreDNS is running
- AWS VPC CNI is running
- kube-proxy is running

These are important because:

- CoreDNS allows services to find each other by name
- AWS VPC CNI gives pod networking and pod IP addresses
- kube-proxy manages Kubernetes service networking
- nodes must be Ready before app pods can run

### Why Ingress Is Installed In The Infrastructure Pipeline

Ingress is part of the platform layer.

The application pipeline deploys app services, but the infrastructure pipeline prepares the cluster entry point.

NGINX ingress helps route external traffic into the Kubernetes cluster.

The workflow waits for:

```text
NGINX controller deployment
  |
  v
ingress-nginx-controller service
  |
  v
AWS LoadBalancer hostname or IP
```

This proves the cluster can receive external traffic.

### Best Practices Used

- Apply runs only after code is pushed to `main` or manually triggered.
- Production environment protection can require manual approval.
- Terraform version is pinned.
- Helm and kubectl are installed explicitly.
- AWS region has a fallback.
- Sensitive variables are injected through GitHub Secrets.
- EKS readiness is checked before installing ingress.
- Failed ingress releases are cleaned carefully.
- Workflow prints useful outputs for the application pipeline.
- `cancel-in-progress` is false so production apply is not interrupted halfway.

## 8. Infrastructure Destroy Workflow

### What It Does

The destroy workflow is defined in:

```text
.github/workflows/infra-destroy.yml
```

It destroys the production infrastructure.

This is useful when:

- the team wants to reduce AWS cost
- the environment needs to be recreated from scratch
- the demo/testing environment is no longer needed

### Why It Is Dangerous

`terraform destroy` can permanently remove production resources.

It can delete:

- EKS cluster
- RDS database
- VPC and subnets
- NAT gateways
- ECR repositories if managed by Terraform
- S3 buckets if managed by Terraform
- RabbitMQ release
- DNS records

That is why the workflow requires explicit confirmation.

### Required Confirmation

The workflow requires the user to type:

```text
DESTROY
```

If the user does not type this exact value, the workflow stops.

### Step Order

| Order | Step | What It Means |
| --- | --- | --- |
| 1 | Manual trigger | User starts workflow manually |
| 2 | Confirm `DESTROY` | Safety check before deleting resources |
| 3 | Checkout code | Downloads repository code |
| 4 | Configure AWS credentials | Allows workflow to delete AWS resources |
| 5 | Setup Terraform | Installs Terraform |
| 6 | Setup Helm | Installs Helm |
| 7 | Terraform init | Connects to backend state |
| 8 | Destroy plan | Shows what will be deleted |
| 9 | Update kubeconfig | Tries to connect to EKS |
| 10 | Uninstall NGINX ingress | Removes ingress if cluster still exists |
| 11 | Uninstall AWS Load Balancer Controller | Removes controller if installed |
| 12 | Terraform destroy | Deletes AWS infrastructure |

### Important Commands

```bash
terraform init
terraform plan -destroy -no-color
aws eks update-kubeconfig --region us-east-1 --name securestay-eks
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall aws-load-balancer-controller -n kube-system
terraform destroy -auto-approve -input=false
```

### Best Practices Used

- Destroy is manual only.
- Destroy requires exact confirmation text.
- Destroy runs in the `production` environment.
- Destroy plan runs before destroy.
- Kubernetes add-ons are removed before deleting AWS resources.
- Some cleanup steps use `continue-on-error` because the cluster may already be partially deleted.

## 9. Terraform Backend And State

### What Is Terraform State?

Terraform state is a record of what Terraform created.

Terraform uses state to know:

- which AWS resources already exist
- which resources need to be changed
- which resources should be destroyed
- how modules and resources are connected

### Where State Is Stored In This Project

This project stores state in S3:

```text
securestay-terraform-state-209998132740/prod/terraform.tfstate
```

It uses DynamoDB for locking:

```text
securestay-terraform-locks
```

### Why Remote State Is Important

Remote state is important because GitHub Actions and local developers need to use the same infrastructure state.

If everyone used local state files, Terraform could become confused and create duplicate or broken resources.

### Why State Locking Is Important

State locking prevents two Terraform operations from running at the same time.

Example problem without locking:

```text
Developer A runs terraform apply
GitHub Actions also runs terraform apply
Both try to update the same infrastructure
State becomes unsafe or incorrect
```

DynamoDB locking prevents this situation.

## 10. GitHub Secrets Used By The Infrastructure Pipeline

The pipeline needs secrets because it must authenticate to AWS and pass sensitive Terraform variables.

Common secrets:

| Secret | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS access key for the pipeline user |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for the pipeline user |
| `AWS_REGION` | AWS region, usually `us-east-1` |
| `TF_VAR_db_password` | RDS PostgreSQL password |
| `TF_VAR_rabbitmq_password` | RabbitMQ admin password |

Important:

- Never commit these values into Git.
- Store them in GitHub Secrets.
- Do not show them in demo videos.
- Rotate them if they are accidentally exposed.

## 11. Best Practices In This Project

### 11.1 Infrastructure As Code

All cloud resources are written in Terraform.

Why it matters:

- repeatable environment creation
- easier code review
- easier disaster recovery
- less manual AWS Console work

### 11.2 Module-Based Terraform Structure

The project separates infrastructure into modules:

```text
network
iam
ecr
storage
compute
database
rabbitmq
dns
```

Why it matters:

- code is easier to understand
- each module has one responsibility
- debugging is easier
- future changes are safer

### 11.3 Plan Before Apply

The project uses `terraform plan` before `terraform apply`.

Why it matters:

- shows what will change
- helps catch accidental deletes
- makes reviews safer
- improves team confidence

### 11.4 Remote Backend

State is stored in S3 and locked with DynamoDB.

Why it matters:

- GitHub Actions and local developers share the same state
- prevents state loss
- prevents parallel state modification

### 11.5 Pinned Tool Versions

Terraform is pinned to:

```text
1.7.5
```

Why it matters:

- avoids surprise behavior from version changes
- makes pipeline runs more consistent
- helps debugging because everyone uses the same tool version

### 11.6 GitHub Environment Protection

The apply and destroy workflows use:

```text
environment: production
```

Why it matters:

- production changes can require approval
- accidental changes are reduced
- the workflow is safer for demos and group projects

### 11.7 Safe Destroy

Destroy requires manual input:

```text
DESTROY
```

Why it matters:

- prevents accidental deletion
- makes the user intentionally confirm the action
- protects costly or important resources

### 11.8 Readiness Checks

The apply workflow checks EKS health before moving forward.

Why it matters:

- avoids deploying ingress before Kubernetes is ready
- gives clearer error messages
- reduces pipeline flakiness

### 11.9 Secrets Management

Sensitive values are passed through GitHub Secrets.

Why it matters:

- prevents passwords from being committed to Git
- keeps credentials out of source code
- supports safer collaboration

### 11.10 Useful Outputs

The apply workflow prints:

```text
RDS endpoint
DATABASE_URL format
ECR repository URLs
```

Why it matters:

- application pipeline needs these values
- team members can configure app deployment correctly
- reduces manual searching in AWS Console

## 12. Correct Beginner Workflow For Making A Change

When changing infrastructure, follow this order:

1. Edit Terraform code in `modules/` or `environments/prod/`.

2. Format the code locally.

```bash
terraform fmt -recursive
```

3. Validate locally if possible.

```bash
cd environments/prod
terraform init
terraform validate
```

4. Push to a branch and open a pull request.

5. Wait for `Infrastructure Plan`.

6. Read the Terraform plan carefully.

7. Merge only if the plan looks correct.

8. Let `Infrastructure Apply` run.

9. Check the final outputs and EKS health.

10. Run the application pipeline after infrastructure is healthy.

## 13. How To Read A Terraform Plan

Terraform plan symbols:

| Symbol | Meaning |
| --- | --- |
| `+` | Terraform will create a resource |
| `~` | Terraform will update a resource |
| `-` | Terraform will delete a resource |
| `-/+` | Terraform will replace a resource |

Be careful with:

```text
- destroy
- replacement
- database changes
- VPC/subnet changes
- EKS cluster replacement
```

If a plan wants to replace RDS or EKS, stop and review before applying.

## 14. Common Mistakes To Avoid

- Do not commit AWS keys or passwords.
- Do not run `terraform apply` from multiple places at the same time.
- Do not ignore Terraform state lock errors.
- Do not run `terraform destroy` unless you really want to delete the environment.
- Do not skip the plan review.
- Do not deploy the application before EKS and ingress are healthy.
- Do not use `terraform apply -lock=false` unless you fully understand the risk.
- Do not manually change AWS resources from the console unless needed for emergency debugging.

## 15. Simple Mental Model

Think about the infrastructure pipeline like this:

```text
Terraform code = blueprint
Terraform plan = preview
Terraform apply = build
Terraform state = memory
DynamoDB lock = safety lock
GitHub Actions = automation worker
AWS = real building site
kubectl = Kubernetes control tool
Helm = Kubernetes package installer
```

For a beginner, the most important idea is:

```text
The pipeline does not just run commands. It protects the cloud environment by running the right commands in the right order.
```

## 16. Final Summary

The SecureStay infrastructure pipeline is responsible for creating and maintaining the AWS platform.

It uses Terraform to create infrastructure, GitHub Actions to automate the process, S3 and DynamoDB to protect state, and Kubernetes tools to prepare EKS for the application.

The correct order is:

```text
Plan first
Review changes
Apply infrastructure
Check EKS readiness
Install ingress
Print outputs
Deploy application
```

This order is important because each stage depends on the previous one. The application can only be deployed successfully after the infrastructure platform is healthy.
