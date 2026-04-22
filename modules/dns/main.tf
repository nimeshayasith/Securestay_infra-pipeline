# Looks up the ALB created by the NGINX Ingress Controller / AWS LB Controller
data "aws_lb" "ingress" {
  count = var.hosted_zone_id != "" ? 1 : 0

  tags = {
    "kubernetes.io/cluster/securestay-eks" = "owned"
  }
}

resource "aws_route53_record" "app" {
  count   = var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "app.securestay.com"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress[0].dns_name
    zone_id                = data.aws_lb.ingress[0].zone_id
    evaluate_target_health = true
  }
}
