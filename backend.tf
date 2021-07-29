terraform {
  required_version = ">= 0.12.2"

  required_providers {
    aws        = ">= 2.0, < 4.0"
    template   = "~> 2.0"
    null       = "~> 2.0"
    local      = "~> 1.3"
    kubernetes = "~> 1.11"
  }

  backend "s3" {
    region         = "us-gov-west-1"
    bucket         = "devsecops-group-dev-terraform-state"
    key            = "gitlab-cluster.terraform.tfstate"
    dynamodb_table = "devsecops-group-dev-terraform-state-lock"
    profile        = "mfa"
    role_arn       = ""
    encrypt        = "true"
  }
}

provider "aws" {
  region  = var.region
  profile = "mfa"
}