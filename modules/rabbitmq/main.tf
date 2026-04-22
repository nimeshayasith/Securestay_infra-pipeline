resource "helm_release" "rabbitmq" {
  name             = "rabbitmq"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "rabbitmq"
  namespace        = "messaging"
  create_namespace = true
  version          = "12.5.0"

  wait              = var.rabbitmq_wait
  wait_for_jobs     = false
  timeout           = var.rabbitmq_timeout
  atomic            = false
  cleanup_on_fail   = false
  dependency_update = true
  max_history       = 1

  values = [file("${path.module}/../../helm/rabbitmq-values.yaml")]

  set {
    name  = "service.type"
    value = var.rabbitmq_service_type
  }

  set {
    name  = "persistence.enabled"
    value = tostring(var.rabbitmq_persistence_enabled)
  }

  set {
    name  = "metrics.enabled"
    value = tostring(var.rabbitmq_metrics_enabled)
  }

  set {
    name  = "resources.requests.cpu"
    value = var.rabbitmq_requests_cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.rabbitmq_requests_memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.rabbitmq_limits_cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.rabbitmq_limits_memory
  }

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_password
  }
}
