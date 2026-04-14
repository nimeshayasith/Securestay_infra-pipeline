# CLAUDE.md — SecureStay Infrastructure Pipeline
# Repository: https://github.com/nimeshayasith/Securestay_infra-pipeline.git

> **Status:** Empty repository — infrastructure to be created from scratch using Terraform.
> **Author role:** Senior DevOps / Cloud Engineer
> **Cloud Provider:** AWS (Region: us-east-1)
> **IaC Tool:** Terraform (modules pattern, remote S3 backend)
> **CI/CD:** GitHub Actions
> **Container Orchestration:** AWS EKS (Kubernetes)

---

## 1. Project Overview

This repository owns **all AWS infrastructure** for the SecureStay hotel booking system.
Nothing is created manually in the AWS Console. Every resource — networking, compute,
storage, DNS, IAM, and container registry — is declared in Terraform and deployed through
a GitHub Actions pipeline.

---

## 2. Database Architecture Decision — Read This First

SecureStay uses a **single shared AWS RDS PostgreSQL instance** for all four microservices.
There is **no in-cluster database of any kind**. This is a firm architectural decision.

| Service | Tables Used |
|---|---|
| `auth-service` | `users` |
| `booking-service` | `hotels`, `rooms`, `bookings` |
| `payment-service` | `payments` |
| `notification-service` | `notification_logs` (replaces MongoDB) |

**Key rules:**
- No MongoDB. No in-cluster PostgreSQL pods. No DocumentDB.
- `k8s/postgres.yaml` and `k8s/mongodb.yaml` from the app repo are **deleted** — never applied.
- RDS lives in **private subnets only** — never publicly accessible.
- Only EKS worker nodes may connect to RDS on port 5432, enforced by Security Group.
- RabbitMQ remains in-cluster (Helm release inside EKS). It is the only messaging
  infrastructure inside Kubernetes.

---

## 3. What This Pipeline Produces (Deployable Artifacts)

| Deliverable | Tool | Purpose |
|---|---|---|
| EKS Cluster | Terraform | Runs all 5 SecureStay microservice containers |
| VPC + Subnets | Terraform | Isolated, multi-AZ private network |
| IAM Roles + Users | Terraform | Least-privilege access for 4-member team + EKS nodes |
| S3 Bucket (state backend) | Bootstrap (manual once) | Remote Terraform state + DynamoDB locking |
| ECR Repositories | Terraform | 5 isolated image repos, one per microservice |
| RDS PostgreSQL | Terraform | Single shared managed database, all 4 services |
| Security Groups | Terraform | EKS nodes → RDS port 5432 only, no public access |
| RabbitMQ via NLB | Terraform + Helm | In-cluster message broker, internal NLB only |
| Route 53 Records | Terraform | DNS A record pointing to the application ALB |

---

## 4. Repository Folder Structure (Target State)

```
Securestay_infra-pipeline/
│
├── bootstrap/                         # Run ONCE manually — creates S3 + DynamoDB for Terraform state
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── modules/
│   ├── network/                       # VPC, public + private subnets, IGW, NAT GWs, route tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/                           # EKS cluster role, EKS node role, 4 team IAM users
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/                           # ECR repos: one per microservice
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── database/                      # Single RDS PostgreSQL + subnet group + security group
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── schema.sql                 # Unified schema for all 4 services — run once after first apply
│   │
│   ├── compute/                       # EKS cluster, managed node groups, add-ons
│   │   ├── main.tf
│   │   ├── eks-cluster.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── rabbitmq/                      # RabbitMQ Helm release + internal NLB
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── storage/                       # S3 buckets (app assets, access logs)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── dns/                           # Route53 A record for app domain
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   └── prod/
│       ├── main.tf                    # Calls all modules, wires outputs between them
│       ├── variables.tf
│       ├── outputs.tf                 # RDS endpoint, ECR URLs, EKS endpoint
│       ├── terraform.tfvars           # Non-secret values only (committed to Git)
│       └── backend.tf                 # S3 remote backend config
│
├── .github/
│   └── workflows/
│       ├── infra-plan.yml             # PR gate: terraform plan posted as PR comment
│       └── infra-apply.yml            # Merge gate: terraform apply + Helm controller installs
│
├── helm/
│   └── rabbitmq-values.yaml           # Bitnami RabbitMQ chart custom values
│
├── scripts/
│   ├── bootstrap.sh                   # Runs bootstrap/ one time
│   └── run-migrations.sh             # Runs schema.sql against RDS after first apply
│
├── .gitignore
├── .terraform-version                 # Pin: 1.7.5
└── README.md
```

---

## 5. Step-by-Step Implementation

### Step 0 — One-Time Bootstrap (Manual — Never in Pipeline)

The Terraform remote backend (S3 + DynamoDB) must exist before the pipeline can run.
Run this **once** from your local machine as `nimesh-admin`.

```bash
cd bootstrap/
terraform init
terraform apply -auto-approve
```

**`bootstrap/main.tf`:**
```hcl
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tf_state" {
  bucket        = "securestay-terraform-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "securestay-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute { name = "LockID"; type = "S" }
}
```

**After bootstrap — create `environments/prod/backend.tf`:**
```hcl
terraform {
  backend "s3" {
    bucket         = "securestay-terraform-state-<YOUR-ACCOUNT-ID>"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "securestay-terraform-locks"
    encrypt        = true
  }
}
```

---

### Step 1 — Network Module

**Reference:** https://medium.com/aws-in-plain-english/building-your-first-kubernetes-application-with-aws-eks-bc2f1e84118

**Creates:**
- 1 VPC (`10.0.0.0/16`)
- 2 Private subnets AZ1 + AZ2 — EKS nodes + RDS live here
- 2 Public subnets AZ1 + AZ2 — ALB and NAT Gateway EIPs live here
- 1 Internet Gateway
- 2 NAT Gateways (one per AZ — high availability for outbound from private subnets)
- Route tables wired to IGW (public) and NAT GW (private)

**Critical EKS subnet tags — without these the AWS Load Balancer Controller cannot place ELBs:**
```hcl
# modules/network/main.tf

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "securestay-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "securestay-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}
```

**`modules/network/variables.tf`:**
```hcl
variable "vpc_cidr"             { default = "10.0.0.0/16" }
variable "private_subnet_cidrs" { default = ["10.0.1.0/24",   "10.0.2.0/24"]   }
variable "public_subnet_cidrs"  { default = ["10.0.101.0/24", "10.0.102.0/24"] }
variable "availability_zones"   { default = ["us-east-1a", "us-east-1b"] }
variable "cluster_name"         { default = "securestay-eks" }
```

**`modules/network/outputs.tf`:**
```hcl
output "vpc_id"             { value = aws_vpc.main.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
```

---

### Step 2 — IAM Module (4 Team Members + EKS Service Roles)

**Team access model:**

| Member | IAM User | Policy | Can do |
|---|---|---|---|
| Nimesh (you) | `nimesh-admin` | `AdministratorAccess` | Full create/modify/delete all AWS |
| Member 2 | `member2-readonly` | `ReadOnlyAccess` | View/list all resources, no changes |
| Member 3 | `member3-readonly` | `ReadOnlyAccess` | View/list all resources, no changes |
| Member 4 | `member4-readonly` | `ReadOnlyAccess` | View/list all resources, no changes |

```hcl
# modules/iam/main.tf

# Admin user — Nimesh
resource "aws_iam_user" "admin" {
  name = "nimesh-admin"
  tags = { Role = "admin", Project = "securestay" }
}
resource "aws_iam_user_policy_attachment" "admin" {
  user       = aws_iam_user.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Read-only team members
resource "aws_iam_user" "readonly" {
  for_each = toset(["member2-readonly", "member3-readonly", "member4-readonly"])
  name     = each.key
  tags     = { Role = "readonly", Project = "securestay" }
}
resource "aws_iam_user_policy_attachment" "readonly" {
  for_each   = aws_iam_user.readonly
  user       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster" {
  name = "securestay-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Node Role — limited to what nodes actually need
resource "aws_iam_role" "eks_node" {
  name = "securestay-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ])
  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}
```

---

### Step 3 — ECR Module (One Repo Per Microservice)

```hcl
# modules/ecr/main.tf

locals {
  services = [
    "api-gateway",
    "auth-service",
    "booking-service",
    "payment-service",
    "notification-service",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "securestay/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }   # Free AWS native scanning
  encryption_configuration     { encryption_type = "AES256" }

  tags = { Project = "securestay", Service = each.key, ManagedBy = "Terraform" }
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain last 10 images"
      selection    = { tagStatus = "any"; countType = "imageCountMoreThan"; countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}
```

---

### Step 4 — Database Module (Single Shared RDS PostgreSQL)

This module is the **most important change** from a naive multi-database setup.
One RDS instance serves all four microservices. Each service gets its own table namespace.
No in-cluster database pods. No MongoDB. The security group enforces that only EKS
worker nodes can reach port 5432.

```hcl
# modules/database/main.tf

# Security Group — EKS nodes only, port 5432
resource "aws_security_group" "rds" {
  name        = "securestay-rds-sg"
  description = "PostgreSQL access from EKS worker nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "securestay-rds-sg", ManagedBy = "Terraform" }
}

# DB Subnet Group — private subnets only, multi-AZ
resource "aws_db_subnet_group" "securestay" {
  name       = "securestay-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "securestay-db-subnet-group" }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "securestay" {
  identifier            = "securestay-postgres"
  engine                = "postgres"
  engine_version        = "15.4"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100          # Auto-scales storage up to 100 GB
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "securestay"             # Single shared database for all services
  username = var.db_username
  password = var.db_password           # From TF_VAR_db_password GitHub secret

  multi_az             = true          # Standby replica in second AZ
  publicly_accessible  = false         # NEVER expose to the internet
  skip_final_snapshot  = false
  final_snapshot_identifier = "securestay-postgres-final-snapshot"
  deletion_protection  = true          # Prevent accidental destroy

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.securestay.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  performance_insights_enabled = true

  tags = { Project = "securestay", ManagedBy = "Terraform" }

  lifecycle { prevent_destroy = true }
}
```

**`modules/database/outputs.tf`:**
```hcl
output "rds_endpoint" { value = aws_db_instance.securestay.endpoint }
output "rds_port"     { value = aws_db_instance.securestay.port     }
output "rds_db_name"  { value = aws_db_instance.securestay.db_name  }
output "rds_username" { value = aws_db_instance.securestay.username }
```

**`modules/database/schema.sql` — Full unified schema for all four services:**
```sql
-- ============================================================
-- SecureStay Unified PostgreSQL Schema
-- Applied once to the "securestay" database after RDS is ready
-- Run via: scripts/run-migrations.sh OR a Kubernetes Job
-- ============================================================

-- AUTH SERVICE — users table
CREATE TABLE IF NOT EXISTS users (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email      VARCHAR(255) UNIQUE NOT NULL,
  password   VARCHAR(255) NOT NULL,            -- bcrypt hash, never plaintext
  role       VARCHAR(50)  NOT NULL DEFAULT 'customer',  -- 'customer' | 'admin'
  created_at TIMESTAMP   NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- BOOKING SERVICE — hotels, rooms, bookings
CREATE TABLE IF NOT EXISTS hotels (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  location    VARCHAR(255) NOT NULL,
  description TEXT,
  created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rooms (
  id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id        UUID           NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  room_type       VARCHAR(100)   NOT NULL,
  price_per_night NUMERIC(10,2)  NOT NULL,
  is_available    BOOLEAN        NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bookings (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES users(id),
  room_id    UUID        NOT NULL REFERENCES rooms(id),
  check_in   DATE        NOT NULL,
  check_out  DATE        NOT NULL,
  status     VARCHAR(50) NOT NULL DEFAULT 'pending',   -- 'pending' | 'confirmed' | 'cancelled'
  created_at TIMESTAMP   NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- PAYMENT SERVICE — payments table
-- Raw card data is NEVER stored here (PCI-DSS compliance)
CREATE TABLE IF NOT EXISTS payments (
  id           UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id   UUID           NOT NULL REFERENCES bookings(id),
  user_id      UUID           NOT NULL REFERENCES users(id),
  amount       NUMERIC(10,2)  NOT NULL,
  status       VARCHAR(50)    NOT NULL DEFAULT 'pending',  -- 'pending' | 'success' | 'failed'
  processed_at TIMESTAMP,
  created_at   TIMESTAMP      NOT NULL DEFAULT NOW()
);

-- NOTIFICATION SERVICE — replaces MongoDB entirely
-- Stores all consumed RabbitMQ events as durable log records
CREATE TABLE IF NOT EXISTS notification_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  routing_key VARCHAR(255) NOT NULL,
  event_type  VARCHAR(100) NOT NULL,
  payload     JSONB        NOT NULL,           -- Full event payload stored as JSONB
  status      VARCHAR(50)  NOT NULL DEFAULT 'delivered',
  received_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Indexes for notification_logs query performance
CREATE INDEX IF NOT EXISTS idx_notification_received_at
  ON notification_logs (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_event_type
  ON notification_logs (event_type);

-- ============================================================
-- SEED DATA — sample hotels and rooms for demo
-- ============================================================
INSERT INTO hotels (id, name, location, description) VALUES
  ('11111111-1111-1111-1111-111111111111',
   'Grand Colombo Hotel', 'Colombo, Sri Lanka',
   'Luxury hotel in the heart of Colombo'),
  ('22222222-2222-2222-2222-222222222222',
   'Kandy Hills Resort', 'Kandy, Sri Lanka',
   'Scenic mountain resort near the Temple of the Tooth')
ON CONFLICT DO NOTHING;

INSERT INTO rooms (hotel_id, room_type, price_per_night) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Deluxe Single',   85.00),
  ('11111111-1111-1111-1111-111111111111', 'Deluxe Double',  120.00),
  ('11111111-1111-1111-1111-111111111111', 'Suite',          200.00),
  ('22222222-2222-2222-2222-222222222222', 'Standard Single', 60.00),
  ('22222222-2222-2222-2222-222222222222', 'Standard Double', 90.00)
ON CONFLICT DO NOTHING;
```

---

### Step 5 — Compute Module (EKS Cluster)

Matches the architecture in Image 3: private subnets AZ1 + AZ2, EC2 worker nodes,
ELB ingress, multi-AZ pod replica sets.

```hcl
# modules/compute/eks-cluster.tf

resource "aws_eks_cluster" "securestay" {
  name     = var.cluster_name
  version  = "1.29"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  tags = { Name = "securestay-eks", ManagedBy = "Terraform" }
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.securestay.name
  node_group_name = "securestay-workers"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  instance_types = ["t3.medium"]

  update_config {
    max_unavailable = 1   # Always keep at least 1 node running during updates
  }
}

# Managed add-ons
resource "aws_eks_addon" "coredns"    { cluster_name = aws_eks_cluster.securestay.name; addon_name = "coredns" }
resource "aws_eks_addon" "kube_proxy" { cluster_name = aws_eks_cluster.securestay.name; addon_name = "kube-proxy" }
resource "aws_eks_addon" "vpc_cni"    { cluster_name = aws_eks_cluster.securestay.name; addon_name = "vpc-cni" }
resource "aws_eks_addon" "ebs_csi"    { cluster_name = aws_eks_cluster.securestay.name; addon_name = "aws-ebs-csi-driver" }
```

---

### Step 6 — RabbitMQ Module (In-Cluster Helm + Internal NLB)

**Reference:** https://medium.com/awsblogs/rabbitmq-with-elastic-load-balancer-and-auto-scaling-groups-41b4eb88423a

RabbitMQ is deployed inside EKS via Helm and exposed through an **internal** NLB.
Only pods inside the cluster VPC can reach it — it is not accessible from the internet.

```hcl
# modules/rabbitmq/main.tf

resource "helm_release" "rabbitmq" {
  name             = "rabbitmq"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "rabbitmq"
  namespace        = "messaging"
  create_namespace = true
  version          = "12.5.0"
  values           = [file("${path.module}/../../helm/rabbitmq-values.yaml")]

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_password
  }
}
```

**`helm/rabbitmq-values.yaml`:**
```yaml
replicaCount: 3

auth:
  username: securestay_admin
  erlangCookie: "REPLACE_WITH_LONG_RANDOM_SECRET_64_CHARS"

persistence:
  enabled: true
  size: 8Gi
  storageClass: "gp2"

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"  # INTERNAL ONLY

resources:
  requests: { memory: "256Mi", cpu: "250m" }
  limits:   { memory: "512Mi", cpu: "500m" }

metrics:
  enabled: true   # Pre-wired for future Prometheus integration
```

---

### Step 7 — DNS Module (Route 53)

```hcl
# modules/dns/main.tf

data "aws_lb" "ingress" {
  tags = { "kubernetes.io/cluster/securestay-eks" = "owned" }
}

resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = "app.securestay.com"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}
```

---

### Step 8 — Wiring All Modules (`environments/prod/main.tf`)

```hcl
# environments/prod/main.tf

module "network" {
  source               = "../../modules/network"
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
}

module "iam" {
  source = "../../modules/iam"
}

module "ecr" {
  source = "../../modules/ecr"
}

module "database" {
  source                     = "../../modules/database"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  eks_node_security_group_id = module.compute.node_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password   # From TF_VAR_db_password GitHub secret
}

module "compute" {
  source               = "../../modules/compute"
  cluster_name         = var.cluster_name
  private_subnet_ids   = module.network.private_subnet_ids
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_node_role_arn
}

module "rabbitmq" {
  source            = "../../modules/rabbitmq"
  rabbitmq_password = var.rabbitmq_password
}

module "dns" {
  source         = "../../modules/dns"
  hosted_zone_id = var.hosted_zone_id
}

# environments/prod/outputs.tf
output "rds_endpoint"        { value = module.database.rds_endpoint }
output "ecr_repository_urls" { value = { for k, v in module.ecr.repositories : k => v.repository_url } }
output "eks_endpoint"        { value = module.compute.cluster_endpoint }
```

---

## 6. GitHub Actions Pipelines

### Workflow 1 — `infra-plan.yml` (PR Gate)

```yaml
# .github/workflows/infra-plan.yml
name: "Infrastructure Plan"

on:
  pull_request:
    branches: [main]
    paths: ["environments/**", "modules/**", "helm/**"]

permissions:
  contents: read
  pull-requests: write

jobs:
  terraform-plan:
    name: "Terraform Plan"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: environments/prod

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ secrets.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.5"

      - run: terraform fmt -check -recursive
        name: Format Check

      - run: terraform init
        name: Init

      - run: terraform validate
        name: Validate

      - id: plan
        name: Plan
        run: terraform plan -no-color -out=tfplan
        env:
          TF_VAR_db_password:       ${{ secrets.TF_VAR_db_password }}
          TF_VAR_rabbitmq_password: ${{ secrets.TF_VAR_rabbitmq_password }}
        continue-on-error: true

      - uses: actions/github-script@v7
        name: Post Plan to PR
        with:
          script: |
            const outcome = '${{ steps.plan.outcome }}';
            const body = `#### Terraform Plan \`${outcome}\`
            <details><summary>Show Plan</summary>

            \`\`\`\n${{ steps.plan.outputs.stdout }}\`\`\`
            </details>
            *Actor: @${{ github.actor }}*`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            })

      - if: steps.plan.outcome == 'failure'
        run: exit 1
```

---

### Workflow 2 — `infra-apply.yml` (Deploy on Merge)

```yaml
# .github/workflows/infra-apply.yml
name: "Infrastructure Apply"

on:
  push:
    branches: [main]
    paths: ["environments/**", "modules/**", "helm/**"]

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    name: "Terraform Apply"
    runs-on: ubuntu-latest
    environment: production     # Requires manual approval in GitHub → Settings → Environments
    defaults:
      run:
        working-directory: environments/prod

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ secrets.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.5"

      - run: terraform init
      - run: terraform apply -auto-approve -input=false
        env:
          TF_VAR_db_password:       ${{ secrets.TF_VAR_db_password }}
          TF_VAR_rabbitmq_password: ${{ secrets.TF_VAR_rabbitmq_password }}

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ secrets.AWS_REGION }} --name securestay-eks

      - name: Install AWS Load Balancer Controller
        run: |
          helm repo add eks https://aws.github.io/eks-charts && helm repo update
          helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=securestay-eks \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller

      - name: Install NGINX Ingress Controller
        run: |
          helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
          helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            -n ingress-nginx --create-namespace \
            --set controller.service.type=LoadBalancer

      - name: Print RDS Endpoint (copy to App repo secret as DATABASE_URL)
        run: |
          echo "============================================"
          echo "RDS endpoint — paste into App repo DATABASE_URL secret:"
          terraform output -raw rds_endpoint
          echo ""
          echo "Full DATABASE_URL format:"
          echo "postgresql://<db_username>:<db_password>@$(terraform output -raw rds_endpoint)/securestay?sslmode=require"
          echo "============================================"

      - name: Print ECR URLs
        run: terraform output ecr_repository_urls
```

---

## 7. Terraform Best Practices Applied

| Practice | Implementation |
|---|---|
| Remote state | S3 + DynamoDB locking, encryption enabled |
| Module separation | `network`, `iam`, `ecr`, `database`, `compute`, `rabbitmq`, `storage`, `dns` |
| Secrets handling | All passwords via GitHub Secrets → `TF_VAR_*` env → Terraform `variable` — never in code |
| Output wiring | All cross-module references via strongly-typed `outputs.tf` |
| Universal tagging | `Project`, `Environment`, `ManagedBy = Terraform` on every resource |
| Pinned versions | Terraform 1.7.5 in `.terraform-version`, provider versions locked in `versions.tf` |
| Least privilege | EKS node role limited to ECR pull + VPC CNI only |
| No public database | `publicly_accessible = false`, security group only allows EKS node SG on 5432 |
| Deletion protection | `prevent_destroy` + `deletion_protection = true` on RDS, ECR, S3 state bucket |
| Schema as code | `schema.sql` version-controlled alongside infrastructure |

---

## 8. GitHub Repository Secrets (Infra Repo)

`Settings → Secrets and variables → Actions`:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | nimesh-admin access key |
| `AWS_SECRET_ACCESS_KEY` | nimesh-admin secret key |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `TF_VAR_db_password` | PostgreSQL master password (min 16 chars, no special chars that break DSN) |
| `TF_VAR_rabbitmq_password` | RabbitMQ admin password |

---

## 9. Infrastructure Deployment Order

```
Step 0  bootstrap/       ← Manual, one time only (creates S3 + DynamoDB)
Step 1  modules/iam      ← EKS roles must exist before cluster
Step 2  modules/network  ← VPC must exist before EKS + RDS
Step 3  modules/storage  ← S3 app buckets
Step 4  modules/ecr      ← Repos must exist before the app pipeline runs
Step 5  modules/database ← RDS in private subnets (depends on network + iam for SG)
Step 6  modules/compute  ← EKS cluster (depends on network + iam)
Step 7  modules/rabbitmq ← Helm release (depends on compute — cluster must be Ready)
Step 8  modules/dns      ← After ALB DNS name is known (depends on compute)
```

Terraform resolves this automatically via the dependency graph. The order is shown for
human understanding when debugging apply failures.

---

## 10. Post-First-Deploy: Run Database Migrations

After the first `terraform apply` completes and the RDS endpoint is printed:

```bash
# scripts/run-migrations.sh
# Run from any machine that can reach the private RDS endpoint
# (requires being inside the VPC, or use the Kubernetes Job approach in the App pipeline)

PGPASSWORD=$TF_VAR_db_password psql \
  -h <rds-endpoint-from-terraform-output> \
  -U securestay_admin \
  -d securestay \
  -f modules/database/schema.sql

echo "Schema applied. Seed data loaded."
```

> **Recommended approach:** Let the App pipeline's migration Kubernetes Job handle this automatically.
> See the App CLAUDE.md → Section 6 (Database Migration Job).
> This separates infrastructure concerns from application concerns cleanly.

---

## 11. Future Improvements (Not in Current Scope)

- **Trivy** — Scan EKS node AMIs and container images for CVEs
- **tflint / checkov** — Static analysis and security checks for Terraform code in PR gate
- **Prometheus + Grafana** — Cluster metrics, RabbitMQ queue depth, RDS connection count
- **AWS WAF** — Web Application Firewall in front of the ALB for OWASP protection
- **AmazonMQ** — Replace in-cluster RabbitMQ with AWS managed message broker
- **AWS Secrets Manager + External Secrets Operator** — Inject DB password into Kubernetes
  Secret from Secrets Manager rather than from GitHub Actions at deploy time
- **Multi-region RDS Read Replica** — us-west-2 read replica for disaster recovery
- **Terraform Cloud** — Replace S3 backend with Terraform Cloud for team plan approval workflow

---

## 12. Current Status

```
Repository state  : EMPTY — create from scratch using this guide
Terraform version : 1.7.5 (pin in .terraform-version)
AWS Region        : us-east-1
EKS cluster name  : securestay-eks
Database          : Single shared AWS RDS PostgreSQL 15.4 (db name: securestay)
In-cluster DB     : NONE — k8s/postgres.yaml and k8s/mongodb.yaml are deleted
In-cluster queue  : RabbitMQ via Helm (stays in EKS)
Team              : 4 members — Nimesh (admin) + 3 read-only
Domain            : app.securestay.com (update with actual Route53 hosted zone)
```

**Next immediate actions (in order):**
1. Clone the empty infra repo locally
2. Create folder structure exactly as shown in Section 4
3. Run `bootstrap/` manually once
4. Implement modules: `network` → `iam` → `ecr` → `database` → `compute` → `rabbitmq` → `dns`
5. Commit `modules/database/schema.sql` with the full schema above
6. Add all GitHub Secrets (Section 8)
7. Open a PR — `infra-plan.yml` posts the Terraform plan as a PR comment
8. Review the plan, approve and merge — `infra-apply.yml` deploys everything
9. Copy the printed RDS endpoint into the App repo `DATABASE_URL` secret
10. Hand ECR repository URLs to Member 4 (DevOps) for the App pipeline
