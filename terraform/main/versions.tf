terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # bucket, key y region se pasan con -backend-config (ver infra/README.md)
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "passfly"
      ManagedBy = "terraform"
      Stack     = "app"
    }
  }
}
