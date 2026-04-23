# Demo Image Generation Prompts

## 1. Purpose Of This Document

This document contains prompts for creating visual diagrams for the SecureStay demo video and presentation.

The images should help explain what the group built:

- overall project journey
- AWS cloud infrastructure
- local development infrastructure
- application pipeline
- infrastructure pipeline

Recommended image style:

```text
Clean modern cloud architecture diagram, professional university project style, clear labels, readable text, balanced spacing, white or light background, blue and green accent colors, 16:9 widescreen format.
```

Avoid:

- too much tiny text
- random decorative icons
- fake secret values
- overly complex arrows
- dark background if it reduces readability

## 2. Image 01: Overall What We Did

### Goal

Show the complete journey from web application development to cloud automation.

### Resources To Include

- SecureStay web application
- microservices
- Docker containers
- local testing
- Minikube
- Terraform
- AWS infrastructure
- EKS
- RDS PostgreSQL
- RabbitMQ
- GitHub Actions pipelines
- users accessing the final application

### Prompt

```text
Create a professional 16:9 architecture journey diagram titled "SecureStay: From Local Development To AWS Cloud Automation".

Show the flow from left to right:
1. Developers building a SecureStay hotel booking web application on Windows.
2. Microservices layer with labeled services: Frontend, API Gateway, Auth Service, Booking Service, Payment Service, Notification Service.
3. Containerization layer using Docker containers.
4. Local testing layer using Docker Desktop and Minikube.
5. Infrastructure as Code layer using Terraform.
6. AWS cloud platform layer with EKS, RDS PostgreSQL, ECR, S3, IAM, VPC, RabbitMQ, and Load Balancer.
7. Automation layer using GitHub Actions with two pipelines: Infrastructure Pipeline and Application Pipeline.
8. Final user accessing SecureStay through a public endpoint.

Use simple cloud icons, Kubernetes icons, container icons, and pipeline icons. Use clear arrows between stages. Keep labels readable. Use a clean white background with blue, green, and orange accent colors. Make it look like a university cloud computing project presentation diagram.
```

### Optional Negative Prompt

```text
Do not include passwords, access keys, random code blocks, unreadable tiny labels, or unrelated cloud providers.
```

### Suggested Use In Demo

Use this image in Kaweesha's introduction.

It should appear near the start of the video to help viewers understand the full project flow.

## 3. Image 02: Cloud Infrastructure Architecture With AWS Resources

### Goal

Show how the AWS production infrastructure is organized.

### Resources To Include

- AWS Cloud boundary
- VPC
- public subnets
- private subnets
- Internet Gateway
- NAT Gateways
- route tables
- EKS cluster
- EKS worker nodes
- NGINX ingress controller
- AWS Load Balancer
- RDS PostgreSQL
- ECR repositories
- S3 buckets
- DynamoDB Terraform lock table
- IAM roles
- Route 53 DNS
- RabbitMQ inside EKS

### Prompt

```text
Create a detailed but readable 16:9 AWS cloud infrastructure architecture diagram titled "SecureStay AWS Cloud Infrastructure".

Draw a large AWS Cloud boundary. Inside it, draw one VPC named "securestay-vpc". Split the VPC into two Availability Zones. In each Availability Zone, show one public subnet and one private subnet.

In the public subnets, show:
- Internet Gateway connected to the internet
- NAT Gateway
- external AWS Load Balancer for ingress traffic

In the private subnets, show:
- EKS worker nodes
- SecureStay application pods
- RabbitMQ running inside Kubernetes

Outside the VPC but still inside AWS, show:
- ECR repositories for Docker images
- S3 bucket for Terraform state
- DynamoDB table for Terraform state locking
- IAM roles for EKS cluster and worker nodes
- Route 53 DNS record for app.securestay.com

Show RDS PostgreSQL in private networking with a label "securestay database". Connect application pods to RDS PostgreSQL. Connect EKS worker nodes to ECR for pulling images. Connect GitHub Actions and Terraform to AWS resources. Show users entering through Route 53 and Load Balancer into NGINX ingress, then to frontend and backend services.

Use AWS-style orange accents, Kubernetes blue, database green, and network gray. Use clean labels and arrows. Keep the diagram professional and not overcrowded.
```

### Optional Negative Prompt

```text
Do not show real AWS account IDs, real passwords, secret keys, or unnecessary services not used in the project.
```

### Suggested Use In Demo

Use this image during Nimesh's Terraform and AWS infrastructure explanation.

It should support the explanation of VPC, subnets, NAT Gateway, EKS, RDS, ECR, S3, DynamoDB, IAM, and ingress.

## 4. Image 03: Local Infrastructure Architecture

### Goal

Show how the team developed and tested the application locally before AWS.

### Resources To Include

- Windows laptop
- Docker Desktop
- Docker Compose
- Docker containers
- Minikube
- local Kubernetes cluster
- PostgreSQL container
- RabbitMQ container
- MongoDB container if explaining early local version
- frontend
- gateway
- auth service
- booking service
- payment service
- notification service
- Docker Hub or local Docker images

### Prompt

```text
Create a 16:9 local development infrastructure diagram titled "SecureStay Local Development Environment".

Show a Windows developer laptop as the main boundary. Inside the laptop, show two local execution options:

Option 1: Docker Compose local stack.
Include Docker Desktop, Docker Compose, and containers for Frontend, API Gateway, Auth Service, Booking Service, Payment Service, Notification Service, PostgreSQL, RabbitMQ, and MongoDB.

Option 2: Minikube local Kubernetes stack.
Include Minikube, a local Kubernetes cluster, pods for the same microservices, Kubernetes services, and local port-forwarding to the frontend.

Show a developer browser accessing http://localhost:3001. Show arrows from frontend to API Gateway, then to backend microservices. Show backend services connecting to PostgreSQL and RabbitMQ. Show Docker images being built locally and optionally pushed to Docker Hub or reused by Minikube.

Use a friendly but technical style, clean layout, readable labels, blue Docker accents, Kubernetes blue, and green database icons. Make it clear this is a local Windows development setup before AWS deployment.
```

### Optional Negative Prompt

```text
Do not make the local setup look like AWS. Do not include cloud load balancers or cloud NAT gateways in this image.
```

### Suggested Use In Demo

Use this image during Lasindu's local demo.

It should help explain Docker Compose and Minikube before showing the running local app.

## 5. Image 04: Application Pipeline Creation

### Goal

Show how application code becomes running services in EKS.

### Resources To Include

- GitHub app repository
- push to `aws_cloud` branch
- GitHub Actions
- image tag generation
- Docker build matrix
- frontend image
- api-gateway image
- auth-service image
- booking-service image
- payment-service image
- notification-service image
- AWS ECR
- Kubernetes secrets
- Helm chart
- EKS namespace `securestay`
- rollout verification
- public frontend endpoint

### Prompt

```text
Create a 16:9 DevOps pipeline diagram titled "SecureStay Application Pipeline".

Show the flow from left to right:
1. Developer pushes application code to GitHub branch "aws_cloud".
2. GitHub Actions starts "App Pipeline - Build -> Push -> Deploy".
3. Prepare step generates an image tag using timestamp and short commit SHA.
4. Build matrix builds Docker images for six services: frontend, api-gateway, auth-service, booking-service, payment-service, notification-service.
5. Docker images are pushed to AWS ECR repositories under securestay/.
6. Deployment job updates kubeconfig for EKS.
7. Pipeline creates Kubernetes secrets for DATABASE_URL, RABBITMQ_URL, JWT_SECRET, and PAYMENT_SECRET.
8. Pipeline runs preflight checks for cluster pod capacity and RabbitMQ readiness.
9. Helm upgrade/install deploys the securestay chart into namespace "securestay".
10. Kubernetes rollout checks verify all deployments are healthy.
11. Users access the final frontend service through a public endpoint.

Use clear pipeline boxes, arrows, GitHub Actions icon style, Docker image icons, AWS ECR registry, Helm chart icon, Kubernetes/EKS cluster, and green check marks for successful verification. Keep text readable and use a clean professional presentation style.
```

### Optional Negative Prompt

```text
Do not display actual secret values, AWS access keys, or real passwords. Do not show unrelated CI tools.
```

### Suggested Use In Demo

Use this image during Diani's application pipeline section.

It should appear when explaining how one code push builds and deploys all services.

## 6. Image 05: Infrastructure Pipeline Creation

### Goal

Show how Terraform and GitHub Actions create, update, and destroy AWS infrastructure.

### Resources To Include

- infrastructure GitHub repository
- Terraform modules
- GitHub Actions workflows
- `infra-plan.yml`
- `infra-apply.yml`
- `infra-destroy.yml`
- Terraform remote backend
- S3 state bucket
- DynamoDB lock table
- AWS credentials from GitHub secrets
- Terraform plan
- Terraform apply
- Terraform destroy
- AWS resources created
- EKS readiness checks
- ingress installation
- outputs for RDS and ECR

### Prompt

```text
Create a 16:9 DevOps infrastructure pipeline diagram titled "SecureStay Infrastructure Pipeline With Terraform".

Show the flow from left to right:
1. Developer updates Terraform code in the infrastructure repository.
2. GitHub Actions Infrastructure Plan workflow runs terraform fmt, terraform init, terraform validate, and terraform plan.
3. Terraform uses remote backend: S3 bucket for state and DynamoDB table for state locking.
4. After approval or main branch update, Infrastructure Apply workflow runs terraform apply.
5. Terraform creates AWS resources using modules: network, IAM, ECR, storage, compute, database, RabbitMQ, DNS.
6. AWS resources appear: VPC, public subnets, private subnets, Internet Gateway, NAT Gateways, EKS cluster, worker nodes, RDS PostgreSQL, ECR repositories, S3 buckets, IAM roles, RabbitMQ, Route 53.
7. Workflow updates kubeconfig and checks EKS nodes and system add-ons.
8. Workflow installs or verifies ingress-nginx and waits for the LoadBalancer endpoint.
9. Workflow prints RDS endpoint and ECR repository URLs for the app pipeline.
10. Separate manual destroy workflow allows controlled terraform destroy when needed.

Use Terraform purple, AWS orange, Kubernetes blue, and GitHub dark gray accents. Use clear arrows and grouped boxes. Show "Plan", "Apply", and "Destroy" as separate controlled paths. Include lock icon near DynamoDB state lock to show safe concurrency.
```

### Optional Negative Prompt

```text
Do not include real secrets, exact access keys, or unnecessary AWS services. Avoid overcrowding the diagram with tiny Terraform code.
```

### Suggested Use In Demo

Use this image during Nimesh's and Diani's sections.

It explains how Terraform and GitHub Actions work together to manage the AWS platform.

## 7. Optional Extra Image: Local Vs Cloud Comparison

### Goal

Show the difference between local development and AWS deployment.

### Prompt

```text
Create a 16:9 comparison infographic titled "SecureStay Local Environment vs AWS Cloud Environment".

Split the image into two columns.

Left column: Local Environment.
Show Windows laptop, Docker Desktop, Docker Compose, Minikube, local PostgreSQL, local RabbitMQ, localhost frontend, fast development, low cost.

Right column: AWS Cloud Environment.
Show AWS Cloud, VPC, EKS, RDS PostgreSQL, ECR, S3, DynamoDB state lock, IAM, NAT Gateway, Load Balancer, Route 53, GitHub Actions automation, scalable production-like deployment.

At the bottom, show a bridge arrow from local to cloud labeled "Terraform + Docker + Helm + GitHub Actions".

Use simple icons, readable labels, and a clean academic presentation style.
```

### Suggested Use In Demo

Use this as a transition between Lasindu's local demo and Nimesh's AWS infrastructure demo.

## 8. Prompt Quality Checklist

Before generating the final images, check that each prompt includes:

- title
- 16:9 aspect ratio
- main components
- arrows or flow direction
- color/style guidance
- instruction to avoid secrets
- readable labels

## 9. Recommended Image File Names

Use these names when saving generated images:

```text
01-overall-project-journey.png
02-aws-cloud-infrastructure.png
03-local-development-infrastructure.png
04-application-pipeline.png
05-infrastructure-pipeline.png
06-local-vs-cloud-comparison.png
```

## 10. How To Use In The Video

Recommended order:

| Image | Presenter | Demo Moment |
| --- | --- | --- |
| `01-overall-project-journey.png` | Kaweesha | Introduction |
| `03-local-development-infrastructure.png` | Lasindu | Before local Docker/Minikube demo |
| `06-local-vs-cloud-comparison.png` | Lasindu or Nimesh | Transition from local to cloud |
| `02-aws-cloud-infrastructure.png` | Nimesh | Terraform and AWS explanation |
| `05-infrastructure-pipeline.png` | Diani | Infrastructure pipeline explanation |
| `04-application-pipeline.png` | Diani | App pipeline explanation |
