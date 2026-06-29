variable "region" { type = string }

variable "default_tags" {
  type        = map(string)
  description = "Tags applied to all resources via provider default_tags"
}
