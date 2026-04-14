aws_region           = "us-east-1"
cluster_name         = "securestay-eks"
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
db_username          = "securestay_admin"

# db_password and rabbitmq_password are injected at CI/CD time via:
#   TF_VAR_db_password       -> GitHub Secret TF_VAR_db_password
#   TF_VAR_rabbitmq_password -> GitHub Secret TF_VAR_rabbitmq_password
# For local runs, create a gitignored terraform.secrets.auto.tfvars file
# in this directory so Terraform auto-loads the two secret values.

# Uncomment and set once your Route 53 hosted zone is ready:
# hosted_zone_id = "ZXXXXXXXXXXXXXXXXXXXXX"
