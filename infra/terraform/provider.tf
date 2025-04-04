terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~>3.0.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.56.0"
    }
  }
}

# Configuring AWS as the provider
provider "aws" {
  region = var.aws_region
}

# Configuring Docker as the provider
provider "docker" {}
