output "rds_endpoint" {
  value = aws_db_instance.securestay.endpoint
}

output "rds_port" {
  value = aws_db_instance.securestay.port
}

output "rds_db_name" {
  value = aws_db_instance.securestay.db_name
}

output "rds_username" {
  value = aws_db_instance.securestay.username
}
