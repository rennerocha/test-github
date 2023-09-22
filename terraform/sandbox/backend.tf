provider "aws" {
  region = module.global_variables.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${module.global_variables.account_id}:role/OrganizationAccountAccessRole"
  }
}

# Storing the state file in an encrypted s3 bucket
terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    region         = "us-east-1"
    bucket         = "the-project-terraform-state"
    key            = "the_project.sandbox.json"
    encrypt        = true
    dynamodb_table = "the-project-terraform-state"
  }
}

module "global_variables" {
  source = "../modules/global_variables"
}