#------------------------------------------------------------------------------
# General
#------------------------------------------------------------------------------
variable "region" {
  type        = string
  description = "Default AWS region."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Current Environment"
}

variable "prefix" {
  type        = string
  description = "Prefix to prepend to resources (for easy identification)."
}

#------------------------------------------------------------------------------
# Provider
#------------------------------------------------------------------------------
variable "assume_role_arn" {
  type        = string
  description = "AWS role to assume when provisioning resources"
  default     = ""
}

variable "assume_role_external_id" {
  type        = string
  description = "Extenal ID associated with the \"assume_role_arn\"."
  default     = ""
}

#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
variable "cluster_version" {
  type        = string
  description = "EKS Cluster version"
  default     = "1.29"
}

variable "eks_admin_users" {
  description = "IAM users (username) to add to the eks admins group."
  type        = list(string)

  default = []
}

#------------------------------------------------------------------------------
# ROUTE 53
#------------------------------------------------------------------------------
variable "route53_zone_id" {
  type        = string
  description = "Route 53 Zone id."
  default     = null
}