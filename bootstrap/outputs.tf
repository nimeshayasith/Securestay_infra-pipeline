output "state_bucket_name" {
  description = "S3 bucket name — paste into environments/prod/backend.tf"
  value       = aws_s3_bucket.tf_state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB lock table name — paste into environments/prod/backend.tf"
  value       = aws_dynamodb_table.tf_locks.name
}

output "account_id" {
  description = "AWS account ID — needed in backend.tf bucket name"
  value       = data.aws_caller_identity.current.account_id
}
