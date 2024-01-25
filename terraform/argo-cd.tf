#------------------------------------------------------------------------------
# ARGO CD
#------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.53.8"

  create_namespace = true

  values = [
    <<-EOF
    global:
      additionalLabels:
        app.kubernetes.io/part-of: argocd

    server:
      ingress:
        enabled: true
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          # Health Check Settings
          alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
          alb.ingress.kubernetes.io/healthcheck-port: traffic-port
          alb.ingress.kubernetes.io/tags: Name=${local.name}-argocd-ingress
          #Important Note:  Need to add health check path annotations in service level if we are planning to use multiple targets in a load balancer
          alb.ingress.kubernetes.io/healthcheck-path: /
          alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
          alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
          alb.ingress.kubernetes.io/success-codes: "200"
          alb.ingress.kubernetes.io/healthy-threshold-count: "2"
          alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
          ## SSL Settings
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
          alb.ingress.kubernetes.io/certificate-arn: ${aws_acm_certificate.argocd.arn} # ACM ARN
          # SSL Redirect Setting
          alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
          # Merge all ingresses
          alb.ingress.kubernetes.io/group.name: morning-star-group
          # Route53 Settings
          external-dns.alpha.kubernetes.io/hostname: argocd.${local.domain_name}
        ingressClassName: "alb"
        hosts:
          - argocd.${local.domain_name}
        paths:
          - /
        pathType: Prefix

    configs:
      params:
        server.insecure: true
      cm:
        url: "https://argocd.${local.domain_name}"
        admin.enabled: true
        dex.config: |
          connectors:
            - type: github
              id: github
              name: GitHub
              config:
                clientID: ${data.aws_secretsmanager_secret_version.argocd_oidc_client_id.secret_string}
                clientSecret: ${data.aws_secretsmanager_secret_version.argocd_oidc_client_secret.secret_string}
                redirectURI: https://argocd.${local.domain_name}/dex/callback
                loadAllGroups: true
      rbac:
        policy.default: role:readonly
        scopes: "[groups, email]"
        policy.csv: |
          g, joeyomi, role:admin
  EOF
  ]
}
