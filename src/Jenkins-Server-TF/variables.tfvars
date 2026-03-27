# Terraform Variable Values for Jenkins Server
# Modified for AWS Learner Lab and KPS-Enterprise project

vpc-name      = "KPS-Jenkins-vpc"
igw-name      = "KPS-Jenkins-igw"
subnet-name   = "KPS-Jenkins-subnet"
rt-name       = "KPS-Jenkins-route-table"
sg-name       = "KPS-Jenkins-sg"
instance-name = "KPS-Jenkins-server"

# IMPORTANT: Change this to your AWS key pair name before running terraform
key-name      = "YOUR_KEY_PAIR_NAME"

# NOTE: iam-role removed - Learner Lab uses pre-created LabInstanceProfile