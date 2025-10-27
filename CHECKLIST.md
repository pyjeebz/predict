# Deployment Checklist

Use this checklist to track your deployment progress.

## Pre-Deployment

### Prerequisites
- [ ] AWS account with admin access
- [ ] AWS CLI installed
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform >= 1.0 installed
- [ ] Python >= 3.9 installed
- [ ] Git installed (optional)

### AWS Setup
- [ ] EC2 key pair created in AWS Console
- [ ] Note the key pair name
- [ ] Download .pem file (Linux/Mac) or .ppk (Windows)
- [ ] Verify AWS quotas (EC2, VPC, RDS limits)

## Terraform Configuration

- [ ] Navigate to `terraform/` directory
- [ ] Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Edit `terraform.tfvars`:
  - [ ] Set `key_pair_name`
  - [ ] Set `db_password` (secure password)
  - [ ] Adjust `aws_region` if needed
  - [ ] Adjust instance sizes for budget
- [ ] Save the file

## Infrastructure Deployment

- [ ] Run `terraform init`
- [ ] Run `terraform validate`
- [ ] Run `terraform plan` and review
- [ ] Run `terraform apply`
- [ ] Wait for completion (10-15 minutes)
- [ ] Save outputs: `terraform output > outputs.txt`
- [ ] Note the ALB URL from outputs

## Post-Deployment Verification

### Check Infrastructure
- [ ] ALB is accessible (may return 503 initially)
- [ ] Auto Scaling Group created
- [ ] EC2 instances running
- [ ] RDS instance available
- [ ] ElastiCache cluster running
- [ ] Lambda function created
- [ ] S3 bucket created
- [ ] CloudWatch dashboard created

### Verify Networking
- [ ] Security groups configured
- [ ] VPC and subnets created
- [ ] NAT gateways operational
- [ ] Route tables configured

## Lambda Function Setup

- [ ] Navigate to `lambda/` directory
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Build package:
  - Windows: `.\build.ps1`
  - Linux/Mac: `./build.sh`
- [ ] Verify `predictive_scaling.zip` created
- [ ] Update Lambda (done by Terraform or manually via AWS CLI)
- [ ] Test Lambda function (optional)

## Initial Data Collection

- [ ] Navigate to `locust/` directory
- [ ] Install Locust: `pip install -r requirements.txt`
- [ ] Get ALB URL from Terraform outputs
- [ ] Start baseline load test:
  - Windows: `.\run_test.ps1 -TargetHost <ALB_URL> -Scenario baseline`
  - Linux/Mac: `./run_test.sh <ALB_URL> baseline`
- [ ] Let run for at least 24 hours
- [ ] Verify metrics in CloudWatch

### During Data Collection
- [ ] Check CloudWatch metrics periodically
- [ ] Verify ALB request count increasing
- [ ] Monitor EC2 CPU utilization
- [ ] Check Lambda invocations (every 5 min)
- [ ] Review CloudWatch Logs for Lambda

## ML Model Training

**After 24+ hours of data collection:**

- [ ] Navigate to `ml-model/` directory
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Set environment variables:
  - Windows: `. ..\scripts\setup_env.ps1`
  - Linux/Mac: `source ../scripts/setup_env.sh`
- [ ] Verify environment variables set:
  - [ ] `ASG_NAME`
  - [ ] `S3_BUCKET`
  - [ ] `AWS_REGION`
- [ ] Run training: `python train_model.py`
- [ ] Verify model trained successfully
- [ ] Check model uploaded to S3
- [ ] Review training metrics (RMSE, accuracy)

## Load Testing

### Test Scenarios

- [ ] Baseline test (verify setup)
  ```powershell
  .\run_test.ps1 -TargetHost <ALB_URL> -Scenario baseline
  ```

- [ ] Traffic surge test
  ```powershell
  .\run_test.ps1 -TargetHost <ALB_URL> -Scenario surge
  ```

- [ ] Flash sale test
  ```powershell
  .\run_test.ps1 -TargetHost <ALB_URL> -Scenario flash-sale
  ```

- [ ] Sinusoidal pattern
  ```powershell
  .\run_test.ps1 -TargetHost <ALB_URL> -Scenario sinusoidal
  ```

- [ ] Step load test
  ```powershell
  .\run_test.ps1 -TargetHost <ALB_URL> -Scenario step
  ```

### During Tests
- [ ] Monitor ASG capacity changes
- [ ] Watch CloudWatch dashboard
- [ ] Check Lambda logs
- [ ] Verify scaling events
- [ ] Monitor response times

## Monitoring Setup

- [ ] Access CloudWatch Dashboard
- [ ] Verify metrics displaying:
  - [ ] Request count
  - [ ] Response time
  - [ ] CPU utilization
  - [ ] ASG capacity
- [ ] Set up CloudWatch Alarms (optional):
  - [ ] High CPU alarm
  - [ ] Error rate alarm
  - [ ] Failed health checks
- [ ] Test SNS notifications (optional)

### Real-time Monitoring
- [ ] Run monitoring script:
  - Windows: `.\scripts\monitor.ps1`
  - Linux/Mac: `./scripts/monitor.sh`
- [ ] Verify all components showing status

## Validation

### Functional Tests
- [ ] Saleor GraphQL API responds
- [ ] Products can be browsed
- [ ] Search works
- [ ] Cart operations functional
- [ ] Load tests complete successfully

### Scaling Tests
- [ ] Baseline traffic maintains 1-2 instances
- [ ] Surge increases instances
- [ ] Scale-down occurs after load decreases
- [ ] Lambda logs show predictions
- [ ] ASG capacity matches predictions

### Performance Tests
- [ ] Response times < 500ms under normal load
- [ ] Response times < 1s during surge
- [ ] No 5xx errors during scaling
- [ ] Health checks passing

## Production Readiness (Optional)

- [ ] Add SSL certificate to ALB
- [ ] Configure custom domain (Route 53)
- [ ] Restrict security groups (SSH, database)
- [ ] Enable RDS encryption
- [ ] Set up automated backups
- [ ] Configure log retention
- [ ] Add budget alerts
- [ ] Document incident response
- [ ] Set up on-call rotation
- [ ] Prepare runbooks

## Optimization

- [ ] Review CloudWatch metrics
- [ ] Analyze ML model accuracy
- [ ] Adjust scaling thresholds
- [ ] Tune model parameters
- [ ] Optimize instance types
- [ ] Review costs
- [ ] Enable cost allocation tags

## Documentation

- [ ] Document deployment process
- [ ] Record configuration decisions
- [ ] Save Terraform outputs
- [ ] Document custom modifications
- [ ] Create team runbook
- [ ] Share knowledge with team

## Cleanup (When Done)

⚠️ **WARNING: This will delete all resources and data**

- [ ] Backup any important data
- [ ] Export CloudWatch metrics
- [ ] Save ML model from S3
- [ ] Document lessons learned
- [ ] Run `terraform destroy`
- [ ] Verify all resources deleted
- [ ] Check AWS bill for remaining charges
- [ ] Delete S3 bucket manually (if needed)
- [ ] Remove CloudWatch log groups (if needed)

## Troubleshooting Checklist

If something goes wrong:

- [ ] Check CloudWatch Logs
- [ ] Review Terraform state
- [ ] Verify AWS permissions
- [ ] Check security group rules
- [ ] Review EC2 user data logs
- [ ] Test connectivity (SSH, HTTP)
- [ ] Verify DNS resolution
- [ ] Check AWS service health
- [ ] Review cost and billing
- [ ] Consult DEPLOYMENT.md

## Success Criteria

Your deployment is successful when:

- [ ] ✅ All infrastructure deployed
- [ ] ✅ Saleor accessible via ALB
- [ ] ✅ Load tests run successfully
- [ ] ✅ Metrics collected in CloudWatch
- [ ] ✅ ML model trained
- [ ] ✅ Lambda predicts correctly
- [ ] ✅ ASG scales up and down
- [ ] ✅ No errors in logs
- [ ] ✅ Dashboard shows data
- [ ] ✅ Costs within budget

## Notes

Date Started: _______________

Date Completed: _______________

Team Members:
- _______________
- _______________

Issues Encountered:
- _______________
- _______________

Customizations:
- _______________
- _______________

## Next Steps

After successful deployment:

1. [ ] Run for 1 week to collect diverse data
2. [ ] Retrain model weekly
3. [ ] Monitor cost trends
4. [ ] Optimize based on usage
5. [ ] Plan for production launch
6. [ ] Set up alerting
7. [ ] Train team on operations
8. [ ] Create disaster recovery plan

---

**Congratulations on completing your predictive auto-scaling deployment!** 🎉
