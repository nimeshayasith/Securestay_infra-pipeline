variable "rabbitmq_password" {
  description = "RabbitMQ admin password injected via TF_VAR_rabbitmq_password GitHub Secret"
  sensitive   = true
}

variable "rabbitmq_wait" {
  description = "Whether Terraform should wait for the Helm release to become ready"
  type        = bool
  default     = false
}

variable "rabbitmq_timeout" {
  description = "Timeout in seconds for the RabbitMQ Helm release"
  type        = number
  default     = 300
}

variable "rabbitmq_service_type" {
  description = "Kubernetes service type for RabbitMQ"
  type        = string
  default     = "ClusterIP"
}

variable "rabbitmq_persistence_enabled" {
  description = "Whether persistence should be enabled for RabbitMQ"
  type        = bool
  default     = false
}

variable "rabbitmq_metrics_enabled" {
  description = "Whether Prometheus metrics should be enabled for RabbitMQ"
  type        = bool
  default     = false
}

variable "rabbitmq_requests_cpu" {
  description = "CPU request for RabbitMQ"
  type        = string
  default     = "50m"
}

variable "rabbitmq_requests_memory" {
  description = "Memory request for RabbitMQ"
  type        = string
  default     = "128Mi"
}

variable "rabbitmq_limits_cpu" {
  description = "CPU limit for RabbitMQ"
  type        = string
  default     = "250m"
}

variable "rabbitmq_limits_memory" {
  description = "Memory limit for RabbitMQ"
  type        = string
  default     = "256Mi"
}
