data "aws_caller_identity" "current" {}

# ── App Assets Bucket ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "app_assets" {
  bucket = "securestay-app-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "securestay-app-assets"
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }

  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "app_assets" {
  bucket                  = aws_s3_bucket.app_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Access Logs Bucket ────────────────────────────────────────────────────────

resource "aws_s3_bucket" "access_logs" {
  bucket = "securestay-access-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "securestay-access-logs"
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
