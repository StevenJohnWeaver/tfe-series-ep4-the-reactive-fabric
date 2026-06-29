variable "region" { type = string }

variable "environment" {
  type        = string
  description = "Deployment environment label (dev, staging, prod)"
}

variable "default_tags" {
  type        = map(string)
  description = "Tags applied to all resources via provider default_tags"
}
