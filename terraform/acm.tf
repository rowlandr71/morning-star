#------------------------------------------------------------------------------
# ACM
#------------------------------------------------------------------------------
resource "aws_acm_certificate" "argocd" {
  domain_name = "argocd.${local.domain_name}"
  subject_alternative_names = [
    "*.argocd.${local.domain_name}",
  ]

  validation_method = "DNS"

  tags = merge(local.tags, {
    DomainName = "argocd.${local.domain_name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_certificate_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.argocd.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}