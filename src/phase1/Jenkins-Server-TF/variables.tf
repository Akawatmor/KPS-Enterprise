# Terraform Variables for Jenkins Server Infrastructure
# Modified for AWS Learner Lab - removed iam-role variable (not allowed)

variable "vpc-name" {
  description = "Name for the VPC"
  type        = string
}

variable "igw-name" {
  description = "Name for the Internet Gateway"
  type        = string
}

variable "rt-name" {
  description = "Name for the Route Table"
  type        = string
}

variable "subnet-name" {
  description = "Name for the Public Subnet"
  type        = string
}

variable "sg-name" {
  description = "Name for the Security Group"
  type        = string
}

variable "instance-name" {
  description = "Name for the Jenkins EC2 instance"
  type        = string
}

variable "key-name" {
  description = "Name of the SSH key pair (must exist in AWS)"
  type        = string
}

# NOTE: iam-role variable removed - Learner Lab uses pre-created LabInstanceProfile