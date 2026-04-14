resource "helm_release" "rabbitmq" {
  name             = "rabbitmq"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "rabbitmq"
  namespace        = "messaging"
  create_namespace = true
  version          = "12.5.0"

  values = [file("${path.module}/../../helm/rabbitmq-values.yaml")]

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_password
  }
}
