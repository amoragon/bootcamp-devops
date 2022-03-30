terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }

  backend "s3" {
    bucket = "kc-terraform-backend"
    key    = "backend"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "kc_acme_storage" {
  bucket = "${lookup(var.bucket, var.environment)}-${random_string.suffix.result}"

  tags = {
    Name        = lookup(var.bucket, var.environment)
    Environment = var.environment
  }
}

resource "aws_s3_bucket_acl" "kc_acme_storage_acl" {
  bucket = aws_s3_bucket.kc_acme_storage.id
  acl    = "private"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
