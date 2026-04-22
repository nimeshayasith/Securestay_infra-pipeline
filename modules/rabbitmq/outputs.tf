output "rabbitmq_service_name" {
  description = "Helm release name — use as the hostname within the cluster (rabbitmq.messaging.svc.cluster.local)"
  value       = helm_release.rabbitmq.name
}

output "rabbitmq_namespace" {
  value = helm_release.rabbitmq.namespace
}
