# EC2 Instance for Jenkins Server
# Modified for AWS Learner Lab constraints:
# - Instance type: t3.large (max allowed in Learner Lab, was t2.2xlarge)
# - IAM Instance Profile: LabInstanceProfile (pre-existing in Learner Lab)

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t3.large"  # Changed from t2.2xlarge (Learner Lab limit)
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = "LabInstanceProfile"  # Use Learner Lab pre-created profile
  root_block_device {
    volume_size = 30
  }
  user_data = templatefile("./tools-install.sh", {})

  tags = {
    Name = var.instance-name
  }
}