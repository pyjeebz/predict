# Architecture Overview

## System Components

### 1. Application Layer

**Saleor E-Commerce Platform**
- Open-source headless e-commerce framework
- GraphQL API
- Runs on EC2 instances via Docker
- Python/Django based
- Supports product catalog, cart, checkout

### 2. Infrastructure Layer

**VPC (Virtual Private Cloud)**
- CIDR: 10.0.0.0/16
- Multi-AZ deployment
- Public, Private, and Database subnets
- NAT Gateways for outbound traffic
- Internet Gateway for inbound traffic

**Application Load Balancer (ALB)**
- Public-facing
- Distributes traffic across EC2 instances
- Health checks on `/graphql/` endpoint
- HTTP/HTTPS support

**Auto Scaling Group (ASG)**
- Dynamic EC2 instance management
- Min: 1, Max: 10 instances (configurable)
- Launch template with Saleor setup
- Target tracking policies (CPU, Request Count)
- Predictive scaling via Lambda

**EC2 Instances**
- Amazon Linux 2023
- t3.medium (configurable)
- CloudWatch agent installed
- Docker and Docker Compose
- Private subnet deployment

### 3. Database Layer

**RDS PostgreSQL**
- Multi-AZ deployment
- db.t3.medium (configurable)
- Automated backups
- Encryption at rest
- Private subnet deployment

**ElastiCache Redis**
- Session management
- Celery task queue
- Single node (configurable to cluster)
- cache.t3.medium

### 4. ML & Monitoring Layer

**CloudWatch**
- Metrics collection:
  - ALB: Request count, response time
  - EC2: CPU, memory, disk, network
  - ASG: Capacity metrics
  - RDS: CPU, connections
- Custom metrics namespace: SaleorPredictiveScaling
- Dashboard for visualization
- Log groups for Lambda

**Lambda Function**
- Runtime: Python 3.11
- Memory: 512MB
- Timeout: 5 minutes
- Triggered every 5 minutes (EventBridge)
- Loads ML model from S3
- Predicts capacity needs
- Calls Auto Scaling API

**S3 Bucket**
- ML model storage
- Historical metrics backup
- Versioning enabled
- Encryption enabled

**EventBridge (CloudWatch Events)**
- Scheduled trigger for Lambda
- Rate: 5 minutes
- Can be adjusted based on needs

### 5. ML Model

**Type**: Random Forest Regressor (scikit-learn)

**Features**:
1. Request Count (Sum)
2. Response Time (Average)
3. CPU Utilization (Average)
4. Hour of Day (0-23)
5. Day of Week (0-6)

**Target**: Desired ASG Capacity

**Training Data**: Historical CloudWatch metrics

**Prediction Flow**:
```
CloudWatch Metrics → Feature Extraction → Normalization → 
Random Forest → Predicted Capacity → ASG Update
```

## Data Flow

### Request Flow
```
User → ALB → EC2 Instance → 
  ├→ PostgreSQL (product data, orders)
  └→ Redis (sessions, cache)
```

### Metrics Flow
```
EC2/ALB/RDS → CloudWatch Metrics → 
  ├→ Dashboard (visualization)
  ├→ Lambda (predictions)
  └→ S3 (historical data)
```

### Scaling Flow
```
EventBridge (5 min) → Lambda →
  ├→ Collect metrics from CloudWatch
  ├→ Load model from S3
  ├→ Predict capacity
  └→ Update ASG desired capacity
```

### Load Testing Flow
```
Locust → ALB → EC2 Instances →
  ├→ Generate load
  ├→ CloudWatch captures metrics
  └→ Triggers scaling events
```

## Security Architecture

### Network Security
- **Public Subnets**: ALB only
- **Private Subnets**: EC2 instances
- **Database Subnets**: RDS, ElastiCache (isolated)
- **NAT Gateways**: Outbound internet for private subnets

### Security Groups
1. **ALB Security Group**
   - Inbound: 80, 443 from 0.0.0.0/0
   - Outbound: All

2. **EC2 Security Group**
   - Inbound: 8000 from ALB SG, 22 from specified CIDR
   - Outbound: All

3. **RDS Security Group**
   - Inbound: 5432 from EC2 SG
   - Outbound: All

4. **Redis Security Group**
   - Inbound: 6379 from EC2 SG
   - Outbound: All

### IAM Roles

**EC2 Instance Role**:
- CloudWatch Agent policy
- SSM managed instance core
- S3 read access (for configs)

**Lambda Execution Role**:
- CloudWatch Logs (write)
- CloudWatch Metrics (read/write)
- Auto Scaling (read/write)
- S3 (read/write for models)
- SNS (publish notifications)

## Scaling Strategies

### 1. Reactive Scaling (Built-in AWS)
- **CPU Target Tracking**: Scale when CPU > 70%
- **Request Count**: Scale when requests/target > 1000

### 2. Predictive Scaling (ML-based)
- **Time-based prediction**: Uses hour/day patterns
- **Trend analysis**: Learns from historical patterns
- **Proactive scaling**: Scales before load increases
- **Update frequency**: Every 5 minutes

### Combined Approach
Both strategies work together:
- Predictive scaling handles anticipated load
- Reactive scaling handles unexpected spikes
- Provides redundancy and safety

## High Availability

**Multi-AZ Deployment**:
- ALB spans multiple AZs
- ASG distributes instances across AZs
- RDS Multi-AZ with automatic failover
- NAT Gateways in each AZ

**Health Checks**:
- ALB health checks (HTTP 200 on /graphql/)
- ASG instance health (EC2 + ELB)
- RDS automated monitoring
- Lambda retry logic

**Backup & Recovery**:
- RDS automated backups (7-day retention)
- S3 versioning for ML models
- CloudWatch log retention
- Infrastructure as Code (quick redeploy)

## Performance Optimization

**Caching Strategy**:
- Redis for session/application cache
- ALB connection reuse
- CloudWatch metric caching in Lambda

**Database Optimization**:
- RDS Multi-AZ for read replica option
- Connection pooling in Saleor
- Indexed queries

**Auto Scaling**:
- Faster scaling with larger spawn rates
- Predictive pre-scaling reduces latency
- Mix of instance types possible

## Monitoring & Observability

**Key Metrics**:
1. Request count (traffic)
2. Response time (performance)
3. Error rate (reliability)
4. CPU utilization (resource usage)
5. Desired vs actual capacity (scaling effectiveness)
6. Prediction accuracy (ML performance)

**Dashboards**:
- Real-time CloudWatch dashboard
- Locust test results dashboard
- Custom metrics for ML predictions

**Alerts**:
- High CPU alarm
- Failed health checks
- Lambda errors
- Scaling events (via SNS)

## Cost Optimization

**Strategies**:
1. **Right-sizing**: Adjust instance types based on usage
2. **Auto Scaling**: Scale down during low traffic
3. **Spot Instances**: Use for non-critical workloads
4. **Reserved Instances**: For baseline capacity
5. **Data Transfer**: Optimize with CloudFront (optional)

**Cost Breakdown**:
- Compute (EC2): Largest component
- Database (RDS): Second largest
- Networking: ALB + data transfer
- Storage: EBS, S3 (minimal)
- Lambda: Negligible (free tier)

## Future Enhancements

**Short-term**:
- HTTPS with ACM certificate
- Custom domain with Route 53
- Enhanced monitoring dashboards
- SNS notifications for scaling events

**Medium-term**:
- Multi-region deployment
- Advanced ML models (LSTM, Prophet)
- A/B testing for scaling strategies
- Cost optimization algorithms

**Long-term**:
- Kubernetes migration
- Serverless components
- Real-time streaming analytics
- ML model auto-retraining pipeline
