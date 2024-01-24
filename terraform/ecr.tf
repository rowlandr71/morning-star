#------------------------------------------------------------------------------
# ECR Repository
#------------------------------------------------------------------------------
module "ecr_repository" {
  #checkov:skip=CKV_TF_1: "Ensure Terraform module sources use a commit hash" | This is delibrate.
  
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"

  repository_name = "${local.name}-timeoff"

  repository_read_write_access_arns = [data.aws_caller_identity.current.arn, ]
  repository_read_access_arns       = ["*"]
  create_lifecycle_policy           = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  repository_force_delete         = true
  repository_image_tag_mutability = "MUTABLE"

  tags = local.tags
}
