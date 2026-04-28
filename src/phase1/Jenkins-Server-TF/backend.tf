# Terraform Backend Configuration
# Modified for AWS Learner Lab

terraform {
  # OPTION 1: Local backend (recommended for Learner Lab - no S3 setup needed)
  # Uncomment the line below and comment out the S3 backend block
  # backend "local" {}

  # OPTION 2: S3 backend (requires manual S3 bucket and DynamoDB table creation first)
  # In Learner Lab, you must create these resources manually via AWS Console/CLI
  # before using this backend configuration.
  #
  # To create manually:
  #   aws s3 mb s3://kps-terraform-state-ACCOUNT_ID --region us-east-1
  #   aws dynamodb create-table \
  #     --table-name kps-terraform-lock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST \
  #     --region us-east-1
  
  # export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

  backend "s3" {
    #bucket         = "kps-terraform-state-{$AWS_ACCOUNT_ID}"
    region         = "us-east-1"
    key            = "KPS-Enterprise/Jenkins-Server-TF/terraform.tfstate"
    dynamodb_table = "kps-terraform-lock"
    encrypt        = true
  }

  required_version = ">=0.13.0"
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
}