# Deployment Guide

This guide walks you through deploying the predictive scaling system step-by-step.

## Prerequisites Checklist

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Python >= 3.9 installed
- [ ] SSH key pair created in AWS Console
- [ ] Git installed (optional)

## Step-by-Step Deployment

### 1. Prepare AWS Environment

#### Create SSH Key Pair
```bash
# In AWS Console:
# EC2 → Key Pairs → Create Key Pair
# Name: saleor-predictive-scaling-key
# Download the .pem file
```

#### Configure AWS CLI
```bash
aws configure
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: us-east-1
# Default output format: json
```

#### Verify AWS Access
```bash
aws sts get-caller-identity
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region      = "us-east-1"
project_name    = "saleor-predictive-scaling"
environment     = "dev"
key_pair_name   = "saleor-predictive-scaling-key"  # Your key pair name
db_password     = "YourSecurePassword123!"          # Change this!

# Optional: Adjust instance sizes for cost savings
instance_type     = "t3.small"      # Smaller for dev
db_instance_class = "db.t3.small"   # Smaller for dev
min_size          = 1
max_size          = 5
desired_capacity  = 1
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy (this will take 10-15 minutes)
terraform apply

# Save outputs
terraform output > outputs.txt
```

**Important Outputs:**
- `alb_url` - Your application URL
- `autoscaling_group_name` - For ML model configuration

### 4. Verify Infrastructure

```bash
# Check if ALB is healthy
ALB_URL=$(terraform output -raw alb_url)
curl -I $ALB_URL

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name)

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=saleor-predictive-scaling" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table
```

### 5. Wait for Saleor to Initialize

The EC2 instances need time to:
1. Install Docker and dependencies
2. Clone Saleor repository
3. Start Saleor containers
4. Run database migrations

**This takes approximately 10-15 minutes.**

Check progress by SSH-ing into an instance:
```bash
# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=saleor-predictive-scaling" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH into instance
ssh -i path/to/your-key.pem ec2-user@$INSTANCE_IP

# Check Docker containers
sudo docker ps

# View logs
sudo docker logs saleor-platform_api_1
```

### 6. Build and Deploy Lambda Function

**Windows (PowerShell):**
```powershell
cd ..\lambda
.\build.ps1

# Update Lambda function
aws lambda update-function-code `
  --function-name saleor-predictive-scaling-predictive-scaling `
  --zip-file fileb://predictive_scaling.zip
```

**Linux/Mac:**
```bash
cd ../lambda
chmod +x build.sh
./build.sh

# Update Lambda function
aws lambda update-function-code \
  --function-name saleor-predictive-scaling-predictive-scaling \
  --zip-file fileb://predictive_scaling.zip
```

### 7. Initial Data Collection Phase

**The system needs to collect metrics before the ML model can be trained.**

Run baseline load tests for data collection:
```bash
cd ../locust
pip install -r requirements.txt

# Get ALB URL
ALB_URL=$(cd ../terraform && terraform output -raw alb_url)

# Run baseline test for 2 hours (collect initial data)
# Windows
.\run_test.ps1 -TargetHost $ALB_URL -Scenario baseline

# Linux/Mac
./run_test.sh $ALB_URL baseline
```

**Let this run for at least 24 hours to collect meaningful data.**

### 8. Train ML Model

After 24+ hours of data collection:

```bash
cd ../ml-model
pip install -r requirements.txt

# Configure environment
export ASG_NAME=$(cd ../terraform && terraform output -raw autoscaling_group_name)
export S3_BUCKET=$(cd ../terraform && terraform output -raw s3_bucket)
export AWS_REGION=us-east-1

# Windows PowerShell
$env:ASG_NAME = (cd ..\terraform; terraform output -raw autoscaling_group_name)
$env:S3_BUCKET = (cd ..\terraform; terraform output -raw s3_bucket)
$env:AWS_REGION = "us-east-1"

# Train model
python train_model.py
```

### 9. Verify Lambda Function

```bash
# Manually invoke Lambda to test
aws lambda invoke \
  --function-name saleor-predictive-scaling-predictive-scaling \
  --payload '{}' \
  response.json

# View response
cat response.json

# Check CloudWatch logs
aws logs tail /aws/lambda/saleor-predictive-scaling-predictive-scaling --follow
```

### 10. Run Full Load Tests

Now test the predictive scaling:

```bash
cd ../locust

# Test traffic surge
# Windows
.\run_test.ps1 -TargetHost $ALB_URL -Scenario surge

# Linux/Mac
./run_test.sh $ALB_URL surge

# Monitor Auto Scaling in real-time
watch -n 10 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names saleor-predictive-scaling-asg \
  --query "AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]"'
```

## Validation Checklist

After deployment, verify:

- [ ] Infrastructure deployed successfully
- [ ] EC2 instances are running and healthy
- [ ] ALB health checks passing
- [ ] Saleor application accessible via ALB URL
- [ ] RDS database is available
- [ ] ElastiCache Redis is available
- [ ] Lambda function deployed
- [ ] EventBridge rule is enabled
- [ ] CloudWatch dashboard created
- [ ] Metrics being collected
- [ ] Load tests can connect to ALB
- [ ] ML model trained and uploaded to S3
- [ ] Lambda successfully predicts and scales

## Monitoring

### CloudWatch Dashboard
```bash
# Get dashboard URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=saleor-predictive-scaling-dashboard"
```

### Key Metrics to Watch
1. **ALB Request Count** - Should increase during load tests
2. **Target Response Time** - Should remain stable
3. **ASG Desired Capacity** - Should change based on predictions
4. **CPU Utilization** - Should correlate with load

### Real-time Monitoring Commands
```bash
# Watch Auto Scaling Group
watch -n 10 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query "AutoScalingGroups[0].[DesiredCapacity,Instances[*].HealthStatus]"'

# Watch CloudWatch Metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn_suffix) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Troubleshooting

### Issue: Saleor Not Accessible

**Symptoms:** ALB returns 503 or connection timeout

**Solutions:**
1. Check target group health
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

2. SSH into instance and check Docker
   ```bash
   sudo docker ps
   sudo docker logs saleor-platform_api_1
   ```

3. Verify security groups allow traffic on port 8000

### Issue: Lambda Not Scaling

**Symptoms:** Capacity doesn't change during load tests

**Solutions:**
1. Check Lambda logs
   ```bash
   aws logs tail /aws/lambda/saleor-predictive-scaling-predictive-scaling --follow
   ```

2. Verify model exists in S3
   ```bash
   aws s3 ls s3://$(terraform output -raw s3_bucket)/models/
   ```

3. Check IAM permissions for Lambda

### Issue: Model Training Fails

**Symptoms:** "Not enough data to train model"

**Solutions:**
1. Ensure system has been running for 24+ hours
2. Verify CloudWatch metrics exist
   ```bash
   aws cloudwatch list-metrics \
     --namespace AWS/ApplicationELB
   ```

3. Run load tests to generate traffic

## Clean Up

To destroy all resources and stop charges:

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Verify all resources deleted
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=saleor-predictive-scaling" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
```

## Next Steps

1. **Optimize Model**: Retrain with more data for better predictions
2. **Tune Thresholds**: Adjust scaling thresholds based on your traffic
3. **Add Alarms**: Create CloudWatch alarms for critical metrics
4. **Enable HTTPS**: Add SSL certificate to ALB
5. **Multi-Region**: Expand to multiple regions for HA

## Support

If you encounter issues:
1. Check CloudWatch Logs
2. Review Terraform state
3. Verify AWS permissions
4. Check security group rules
5. Review EC2 user data logs: `/var/log/cloud-init-output.log`
