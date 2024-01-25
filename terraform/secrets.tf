#------------------------------------------------------------------------------
# ARGO CD
#------------------------------------------------------------------------------
resource "random_string" "argocd_secrets_salt" {
  length  = 5
  special = false
}

resource "aws_secretsmanager_secret" "argocd_oidc_client_id" {
  name = "${var.environment}-argocd-oidc-client-id-${random_string.argocd_secrets_salt.result}"
  tags = local.tags
}

resource "aws_secretsmanager_secret" "argocd_oidc_client_secret" {
  name = "${var.environment}-argocd-oidc-client-secret-${random_string.argocd_secrets_salt.result}"
  tags = local.tags
}

data "aws_secretsmanager_secret_version" "argocd_oidc_client_id" {
  secret_id = aws_secretsmanager_secret.argocd_oidc_client_id.id
}

data "aws_secretsmanager_secret_version" "argocd_oidc_client_secret" {
  secret_id = aws_secretsmanager_secret.argocd_oidc_client_secret.id
}
