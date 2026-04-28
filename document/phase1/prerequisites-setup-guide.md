# AWS Prerequisites Setup Script

## Overview

This script automatically creates required AWS resources for the KPS-Enterprise deployment:
- SSH Key Pair for EC2 access
- S3 Bucket for Terraform state storage
- DynamoDB Table for Terraform state locking

## Usage

### Automatic Setup (Recommended)

```bash
cd implementation/phase1
./scripts/setup-prerequisites.sh
```

### During Deployment

The `start.sh` script automatically checks for these resources and offers to create them if missing:

```bash
./start.sh
# Will prompt: "Do you want to create them automatically? (yes/no):"
```

## What Gets Created

### 1. SSH Key Pair

- **Name**: `kps-jenkins-key`
- **File**: `~/.ssh/kps-jenkins-key.pem`
- **Permissions**: 400 (read-only)
- **Purpose**: SSH access to Jenkins EC2 instance

**Usage after EC2 creation**:
```bash
ssh -i ~/.ssh/kps-jenkins-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### 2. S3 Bucket

- **Name**: `kps-terraform-state-<YOUR_ACCOUNT_ID>`
- **Region**: us-east-1 (or your configured region)
- **Features**:
  - ✅ Versioning enabled
  - ✅ AES256 encryption
  - ✅ Public access blocked
- **Purpose**: Store Terraform state files

### 3. DynamoDB Table

- **Name**: `kps-terraform-lock`
- **Key**: LockID (String)
- **Billing**: Pay-per-request
- **Purpose**: Terraform state locking (prevent concurrent modifications)

## Multi-Account Compatible

The script is designed to work with **any** AWS Learner Lab account:

- Automatically detects your AWS Account ID
- Creates resources with account-specific names
- No manual ARN or account ID configuration needed
- Works for all team members using Learner Lab

## What Happens Automatically

1. **Checks AWS credentials** - ensures you're logged in
2. **Gets your Account ID** - from `aws sts get-caller-identity`
3. **Checks existing resources** - avoids duplicate creation
4. **Creates missing resources** - only what's needed
5. **Updates Terraform config** - sets correct S3 bucket and key pair names
6. **Saves configuration** - creates `prerequisites-info.txt` for reference

## Output Files

### prerequisites-info.txt

Contains all the resource information:
```bash
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1

KEY_PAIR_NAME=kps-jenkins-key
KEY_PAIR_FILE=/home/user/.ssh/kps-jenkins-key.pem

S3_BUCKET_NAME=kps-terraform-state-123456789012
DYNAMODB_TABLE_NAME=kps-terraform-lock
```

## Terraform Configuration Updates

The script automatically updates:

### backend.tf
```hcl
backend "s3" {
  bucket         = "kps-terraform-state-123456789012"  # Auto-updated
  region         = "us-east-1"
  key            = "KPS-Enterprise/Jenkins-Server-TF/terraform.tfstate"
  dynamodb_table = "kps-terraform-lock"                # Auto-updated
  encrypt        = true
}
```

### variables.tfvars
```hcl
key-name = "kps-jenkins-key"  # Auto-updated
```

## Error Handling

### Key Pair Already Exists in AWS

If the key pair exists in AWS but the local file is missing:

```
[ERROR] Key pair exists in AWS but local file not found: ~/.ssh/kps-jenkins-key.pem

Options:
  1. Delete the key pair in AWS Console and run this script again
  2. Download the key pair manually if you have it
  3. Use a different key pair name by editing this script
```

**Solution**: Delete the key pair in AWS Console → EC2 → Key Pairs, then re-run the script.

### AWS Credentials Not Configured

```
[ERROR] AWS credentials not configured
[INFO] For Learner Lab: Copy credentials from AWS Details → AWS CLI
```

**Solution**: Update `~/.aws/credentials` with your Learner Lab session credentials.

### Insufficient Permissions

If you get permission errors, ensure your Learner Lab session is active and has not expired.

## Manual Cleanup (If Needed)

To remove all created resources:

```bash
# Get your account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Delete key pair
aws ec2 delete-key-pair --key-name kps-jenkins-key
rm ~/.ssh/kps-jenkins-key.pem

# Delete S3 bucket (remove contents first)
aws s3 rb s3://kps-terraform-state-${AWS_ACCOUNT_ID} --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name kps-terraform-lock
```

> ⚠️ **Warning**: Only do this if you want to completely remove the infrastructure. Deleting the S3 bucket will remove your Terraform state!

## Verification

After running the script, verify all resources:

```bash
# Check key pair
aws ec2 describe-key-pairs --key-names kps-jenkins-key
ls -l ~/.ssh/kps-jenkins-key.pem

# Check S3 bucket
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls s3://kps-terraform-state-${AWS_ACCOUNT_ID}

# Check DynamoDB table
aws dynamodb describe-table --table-name kps-terraform-lock
```

## FAQ

**Q: Do I need to run this for every Learner Lab session?**  
A: No, resources persist across sessions within your Learner Lab duration.

**Q: What if my friend wants to deploy in their Learner Lab?**  
A: They just run the same script - it will automatically use their Account ID.

**Q: Can I change the resource names?**  
A: Yes, edit the script variables at the top:
```bash
KEY_PAIR_NAME="kps-jenkins-key"
S3_BUCKET_NAME="kps-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE_NAME="kps-terraform-lock"
```

**Q: Is this safe to run multiple times?**  
A: Yes, the script checks for existing resources and skips creation if they exist.

**Q: What happens to my SSH key if I run this on a different machine?**  
A: The key pair exists in AWS, but you'll need the `.pem` file on each machine. Copy it securely:
```bash
scp ~/.ssh/kps-jenkins-key.pem user@othermachine:~/.ssh/
```

## Integration with Main Deployment

The `start.sh` script automatically:

1. Runs `check_prerequisites()` function
2. Detects missing resources
3. Offers to run `setup-prerequisites.sh`
4. Proceeds with deployment after confirmation

**No manual intervention needed** - just run `./start.sh`!

## Troubleshooting

### Script Fails to Create S3 Bucket

**Error**: `BucketAlreadyOwnedByYou` or `BucketAlreadyExists`

This means the bucket already exists (possibly from a previous run). The script should detect this, but if it doesn't:

```bash
# Check bucket
aws s3 ls s3://kps-terraform-state-$(aws sts get-caller-identity --query Account --output text)
```

If it exists, you're good to proceed with deployment.

### DynamoDB Table Creation Fails

**Error**: `ResourceInUseException`

The table already exists. Verify:

```bash
aws dynamodb describe-table --table-name kps-terraform-lock
```

### Terraform Can't Find Backend

**Error**: `Error: Failed to get existing workspaces: S3 bucket does not exist`

Ensure `backend.tf` has the correct bucket name:

```bash
grep bucket src/Jenkins-Server-TF/backend.tf
```

Should show: `bucket = "kps-terraform-state-<YOUR_ACCOUNT_ID>"`

---

**Last Updated**: 2026-04-01  
**Maintained by**: KPS-Enterprise Team
