terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "3.6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.8.0"
    }
  }

  backend "s3" {
    bucket = "azmina-amplifica-terraform-state"
    key    = "amplifica/terraform.tfstate"
    region = "us-east-1"
  }
}
