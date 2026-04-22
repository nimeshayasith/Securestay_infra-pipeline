# AWS Infrastructure Explained

## 1. Purpose Of This Document

This document explains how the SecureStay cloud infrastructure is built in AWS, service by service, in beginner-friendly language.

The main goal is to answer questions like these:

- How was the network created?
- Why were private and public subnets used?
- How was the database designed?
- How was IAM used?
- How does Kubernetes fit into AWS?

## 2. Terraform Entry Points

There are two important entry points in this repository.

### 2.1 `bootstrap/`

This folder creates the Terraform backend resources:

- S3 bucket for Terraform state
- DynamoDB table for state locking

Why this is needed:

- Terraform needs a place to store the real state of infrastructure.
- In team projects, local state files are risky.
- Remote state makes collaboration safer.

### 2.2 `environments/prod/`

This is the production environment entrypoint.

It does not define every AWS resource directly. Instead, it connects reusable modules together:

- `network`
- `iam`
- `ecr`
- `storage`
- `compute`
- `database`
- `rabbitmq`
- `dns`

This is a clean way to build infrastructure because the environment stays readable while the detailed logic remains inside modules.

## 3. Remote State Infrastructure

Before provisioning the main environment, the project creates a remote backend.

### Resources Created

- S3 bucket for Terraform state
- DynamoDB table for state locking
- versioning enabled on the state bucket
- encryption enabled on the state bucket
- public access blocked on the state bucket

### Why This Is Good Practice

- versioning protects state history
- locking prevents two Terraform runs from changing infrastructure at the same time
- encryption protects sensitive metadata inside the state file
- public access blocking reduces accidental exposure

## 4. Network Infrastructure

The network is built inside a VPC.

### 4.1 VPC

The VPC is the private cloud network created specifically for SecureStay.

Why it exists:

- it isolates the project from other AWS networks
- it gives control over IP ranges, subnets, and routing

### 4.2 Subnets

The project creates:

- 2 public subnets
- 2 private subnets

Why two of each:

- high availability across Availability Zones
- better resilience if one AZ has issues

Why separate public and private subnets:

- public subnets are for internet-facing resources
- private subnets are for internal services and data resources

### 4.3 Internet Gateway

The Internet Gateway attaches the VPC to the internet.

Why it is needed:

- resources in public subnets need a route to the internet

### 4.4 NAT Gateways

The project creates one NAT Gateway per public subnet.

Why this is important:

- private subnet resources can reach the internet for updates
- those private resources still do not accept direct inbound internet traffic

Typical example:

- an EKS worker node in a private subnet can pull a package or container image
- but outside users cannot directly SSH into it from the internet

### 4.5 Route Tables

Route tables define where traffic goes.

The project uses:

- a public route table that sends `0.0.0.0/0` traffic to the Internet Gateway
- private route tables that send `0.0.0.0/0` traffic through NAT Gateways

This is one of the most important network concepts to understand because subnets become "public" or "private" mainly due to routing behavior.

### 4.6 Kubernetes Subnet Tags

The subnets are tagged for Kubernetes load balancer discovery.

Why this matters:

- Kubernetes and AWS controllers use tags to know where to place internal or external load balancers

## 5. IAM Infrastructure

IAM is used for both human access and AWS service access.

### 5.1 IAM Users

The project creates:

- one admin user
- three read-only users

This is useful in a team learning environment because:

- one person can manage infrastructure fully
- others can inspect resources without changing them

### 5.2 EKS Cluster Role

The EKS control plane needs an IAM role so AWS can operate the managed cluster.

Without this role:

- EKS cannot create or manage cluster-level AWS integrations correctly

### 5.3 EKS Node Role

The EC2 worker nodes also need an IAM role.

This role allows them to:

- function as Kubernetes worker nodes
- pull container images from ECR
- use the VPC CNI plugin

This is an example of service-to-service permissions in AWS.

### 5.4 Best Practice Note

The project uses AWS managed policies for simplicity.

That is a good learning step, but in advanced production systems teams often move toward more custom least-privilege policies.

## 6. Compute Infrastructure With EKS

The compute layer is built with Amazon EKS.

### 6.1 EKS Cluster

The EKS cluster is the Kubernetes control plane.

Important design choices in this project:

- Kubernetes version is explicitly declared
- cluster logs are enabled for API, audit, and authenticator events
- both private and public endpoint access are enabled

Why this matters:

- explicit versions reduce surprises
- logs improve debugging and auditing
- public endpoint access makes management easier for a student or small team setup

### 6.2 Worker Nodes

The node group provides the EC2 machines that actually run containers.

This project uses:

- managed node groups
- `t3.micro` instances
- fixed scaling values for desired, minimum, and maximum node counts

Why this is useful:

- managed node groups reduce operational complexity
- small instances keep cost lower for learning environments

### 6.3 EKS Add-ons

The project enables:

- CoreDNS
- kube-proxy
- VPC CNI

These are foundational Kubernetes networking components.

### 6.4 Post-Apply Cluster Tooling

After Terraform apply, the GitHub Actions workflow installs:

- AWS Load Balancer Controller
- NGINX Ingress Controller

Why this matters:

- the AWS Load Balancer Controller helps Kubernetes create AWS load balancers
- the NGINX Ingress Controller helps expose HTTP services into the cluster

## 7. Database Infrastructure

The database layer is built with Amazon RDS for PostgreSQL.

### 7.1 Database Placement

The RDS instance is placed in private subnets using a DB subnet group.

Why this is important:

- the database is not directly exposed to the public internet
- it stays inside the private network boundary

### 7.2 Database Access Control

A dedicated security group allows PostgreSQL traffic on port `5432` only from the EKS worker node security group.

This is an important best practice.

It means:

- not every resource in the VPC can talk to the database
- only the application platform running on EKS is allowed

### 7.3 Database Configuration

This project uses:

- PostgreSQL engine
- `db.t3.micro`
- encrypted storage
- no public accessibility

Why this is beginner-friendly:

- simple
- affordable
- still demonstrates proper placement and access control

### 7.4 Schema Initialization

The repository includes:

- a schema file in `modules/database/schema.sql`
- a helper script in `scripts/run-migrations.sh`

This is helpful because infrastructure creation and database schema creation are related, but not always the same step.

## 8. Storage Infrastructure

The project uses Amazon S3 for object storage.

### Buckets Created

- application assets bucket
- access logs bucket

### Protections Used

- server-side encryption
- public access blocking
- bucket versioning on the app assets bucket

Why these settings are good:

- encryption protects stored data
- public access blocking reduces accidental exposure
- versioning helps recover from accidental overwrites or deletions

## 9. Container Registry Infrastructure

The project uses Amazon ECR to store Docker container images.

### Repositories Created

- `securestay/api-gateway`
- `securestay/auth-service`
- `securestay/booking-service`
- `securestay/payment-service`
- `securestay/notification-service`

### Practices Used

- image scanning on push
- encryption
- lifecycle policy to keep only the latest images

Why this matters:

- image scanning helps identify vulnerabilities
- lifecycle policies reduce unnecessary storage usage
- separate repositories make service boundaries clearer

## 10. Messaging Infrastructure

RabbitMQ is deployed into Kubernetes using Helm.

### Important Choices In This Project

- deployed in its own namespace
- service type is `ClusterIP`
- persistence is disabled
- metrics are disabled
- light CPU and memory requests/limits are used

Why these choices make sense for a learning environment:

- they reduce cost
- they reduce complexity
- they are enough to demonstrate messaging concepts

Production note:

- if message durability is critical, persistence should usually be enabled

## 11. DNS Infrastructure

The project uses Route 53 to create an alias record for `app.securestay.com`.

How it works:

1. An AWS load balancer is created for ingress.
2. Terraform looks up that load balancer.
3. Terraform creates a Route 53 alias record pointing to it.

Why this matters:

- users get a friendly domain name
- the DNS name can stay stable even if the underlying load balancer details are abstracted away

## 12. How Modules Connect To Each Other

Understanding dependencies between modules is a major learning step.

Here is the dependency flow:

```text
network
  -> provides VPC and subnet IDs

iam
  -> provides IAM roles for EKS

compute
  -> needs network + iam
  -> provides cluster outputs and node security group

database
  -> needs network + compute node security group

rabbitmq
  -> needs compute because it deploys into Kubernetes

dns
  -> depends on compute because ingress needs the cluster
```

This modular dependency chain is a strong design practice because each part has a clear responsibility.

## 13. Security Practices Used

This project includes several useful security-oriented decisions:

- private subnets for sensitive resources
- security group restriction for database access
- encryption for S3, ECR, and database storage
- blocked public access on S3 buckets
- secrets passed through GitHub Secrets or local ignored variable files
- remote Terraform state with locking

These practices do not make the system perfect, but they are strong foundational habits.

## 14. Cost And Simplicity Decisions

This project also shows how architecture choices are often tradeoffs between cost, simplicity, and resilience.

Examples:

- `t3.micro` worker nodes reduce cost
- a single small RDS instance reduces cost
- RabbitMQ persistence is disabled to reduce complexity
- managed AWS services reduce administration effort

The important lesson is that cloud architecture is about choosing the right compromise for the current stage of the project.

## 15. Common Operational Lessons From This Project

When working with this infrastructure, some practical lessons become very important:

- Terraform state must stay healthy and locked correctly
- `terraform destroy` can fail when AWS dependencies still exist
- EKS, subnets, internet gateways, and load balancers often have hidden dependency chains
- deletion protection and lifecycle protection can save resources, but they must be understood before destroy operations
- version mismatches, such as EKS cluster version drift, can affect updates

These are real-world cloud engineering lessons, not just theory.

## 16. Beginner-Friendly Mental Model

If you want one simple way to remember the infrastructure, think of it like this:

- VPC is the land
- subnets are the rooms
- route tables are the roads
- IAM is the permission system
- EKS is the application runtime platform
- RDS is the main structured data store
- S3 is file storage
- ECR is the image warehouse
- RabbitMQ is the message courier
- Route 53 is the address book
- Terraform is the blueprint
- GitHub Actions is the automation worker

## 17. Final Summary

The SecureStay AWS infrastructure is a modular cloud platform built around Terraform, EKS, RDS, S3, ECR, IAM, and Route 53.

The most important lessons from this infrastructure are:

- build with modules
- separate network layers clearly
- keep databases private
- use IAM roles intentionally
- automate plan and apply through CI/CD
- prefer managed services when learning or moving quickly
- understand the dependency chain between AWS resources

Once you understand this document well, you are already learning the foundations of real cloud platform engineering.
