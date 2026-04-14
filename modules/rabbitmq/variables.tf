variable "rabbitmq_password" {
  description = "RabbitMQ admin password — injected via TF_VAR_rabbitmq_password GitHub Secret"
  sensitive   = true
}
