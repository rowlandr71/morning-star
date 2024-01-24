#------------------------------------------------------------------------------
# KMS
#------------------------------------------------------------------------------
resource "aws_kms_key" "eks" {
  description             = "AWS KMS for ${local.name_pascal_case}"
  is_enabled              = true
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms_policy.json

  tags = local.tags
}

resource "aws_kms_alias" "eks" {
  target_key_id = aws_kms_key.eks.id
  name          = "alias/${local.name}"
}