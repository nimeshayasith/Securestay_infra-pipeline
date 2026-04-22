# Security Group - only EKS worker nodes can reach RDS on port 5432
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

  tags = {
    Name        = "securestay-rds-sg"
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# DB Subnet Group - private subnets only
resource "aws_db_subnet_group" "securestay" {
  name       = "securestay-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name      = "securestay-db-subnet-group"
    ManagedBy = "Terraform"
  }
}

# RDS PostgreSQL - single shared instance for all four microservices
resource "aws_db_instance" "securestay" {
  identifier            = "securestay-postgres"
  engine                = "postgres"
  engine_version        = "16.4"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "securestay"
  username = var.db_username
  password = var.db_password

  multi_az            = false
  publicly_accessible = false
  apply_immediately   = true

  skip_final_snapshot = true
  deletion_protection = false

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.securestay.name

  # Free Tier accounts can be restricted to a zero-day retention period.
  backup_retention_period      = 0
  maintenance_window           = "Mon:04:00-Mon:05:00"
  performance_insights_enabled = false

  tags = {
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
