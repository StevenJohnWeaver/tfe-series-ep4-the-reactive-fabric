terraform {
  required_version = ">= 1.10.0"

  cloud {
    organization = "steve-weaver-demo-org"
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.28" }
  }
}

# Dynamic credentials: HCP Terraform injects short-lived AWS credentials via
# workspace env vars (TFC_AWS_PROVIDER_AUTH, TFC_AWS_RUN_ROLE_ARN). No static
# keys, no assume_role block needed here.
provider "aws" {
  region = var.region

  default_tags { tags = var.default_tags }
}
