terraform {
  required_version = ">= 1.10.0"

  cloud {
    organization = "steve-weaver-demo-org"
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.28" }
  }
}

provider "aws" {
  region = var.region

  default_tags { tags = var.default_tags }
}
