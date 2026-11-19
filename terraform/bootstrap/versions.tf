terraform {
  required_version = ">= 1.10"

  # bucket, key y region se pasan con -backend-config (lo hace el workflow Bootstrap)
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "passfly"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}
