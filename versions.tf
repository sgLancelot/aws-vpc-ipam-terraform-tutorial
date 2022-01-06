terraform {
  required_version = "~> 1.1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.68" # the minimum version AWS VPC IPAM Terraform resources are released on
    }
  }
}