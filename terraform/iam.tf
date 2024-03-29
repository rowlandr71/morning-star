#------------------------------------------------------------------------------
# General
#------------------------------------------------------------------------------
data "aws_iam_user" "admins" {
  for_each  = toset(var.eks_admin_users)
  user_name = each.key
}

data "aws_iam_role" "ci_runner" {
  name = "ci-runner"
}


#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
module "allow_eks_access_iam_policy" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.30.0"

  name          = "${local.name}-allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks_admins_iam_role" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.30.0"

  role_name         = "${local.name}-eks-admin"
  create_role       = true
  role_requires_mfa = false

  custom_role_policy_arns = [module.allow_eks_access_iam_policy.arn]

  trusted_role_arns = [
    "arn:aws:iam::${module.vpc.vpc_owner_id}:root"
  ]
}

module "allow_assume_eks_admins_iam_policy" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.30.0"

  name          = "${local.name}-allow-assume-eks-admin-iam-role"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = module.eks_admins_iam_role.iam_role_arn
      },
    ]
  })
}

module "eks_admins_iam_group" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.30.0"

  name                              = "${local.name}-eks-admin"
  attach_iam_self_management_policy = false
  create_group                      = true
  group_users                       = var.eks_admin_users
  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn]
}


#------------------------------------------------------------------------------
# KMS
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "kms_policy" {
  #checkov:skip=CKV_AWS_109: "Ensure IAM policies does not allow permissions management / resource exposure without constraints"
  #checkov:skip=CKV_AWS_111: "Ensure IAM policies does not allow write access without constraints"
  #checkov:skip=CKV_AWS_356: "Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions"
  statement {
    sid     = "KeyOwnerPolicy"
    effect  = "Allow"
    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailAccessKMS"
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchAccessKMS"
    effect = "Allow"

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowSecretsManagerAccessKMS"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
      variable = "kms:ViaService"
    }
    resources = ["*"]
  }
}


#------------------------------------------------------------------------------
# ALB INGRESS CONTROLLER
#------------------------------------------------------------------------------
module "aws_load_balancer_controller_irsa_role" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name                              = "${local.name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}


#------------------------------------------------------------------------------
# CLUSTER AUTOSCALER
#------------------------------------------------------------------------------
module "cluster_autoscaler_irsa_role" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name                        = "${local.name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}


#------------------------------------------------------------------------------
# EXTERNAL DNS
#------------------------------------------------------------------------------
module "external_dns_irsa_role" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name                     = "${local.name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.this.arn]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = local.tags
}