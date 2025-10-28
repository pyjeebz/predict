#!/bin/bash
set -e

# Update system
yum update -y

# Install dependencies
yum install -y docker git python3 python3-pip postgresql15

# Start Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "metrics": {
    "namespace": "SaleorPredictiveScaling",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": [
          {"name": "bytes_sent", "rename": "NET_BYTES_SENT", "unit": "Bytes"},
          {"name": "bytes_recv", "rename": "NET_BYTES_RECV", "unit": "Bytes"}
        ],
        "metrics_collection_interval": 60,
        "resources": ["eth0"]
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Clone Saleor repository
cd /home/ec2-user
git clone https://github.com/saleor/saleor-platform.git
cd saleor-platform

# Configure environment variables
cat > .env <<EOF
# Database
DATABASE_URL=postgres://${db_user}:${db_password}@${db_host}:5432/${db_name}

# Redis
REDIS_URL=redis://${redis_host}:6379/0
CELERY_BROKER_URL=redis://${redis_host}:6379/1

# Security
SECRET_KEY=$(openssl rand -base64 32)
ALLOWED_HOSTS=*

# Email (configure based on your needs)
EMAIL_URL=console://

# Saleor settings
DEFAULT_FROM_EMAIL=noreply@example.com
DEBUG=False
EOF

# Create docker-compose override for production
cat > docker-compose.override.yml <<EOF
version: "3.4"

services:
  api:
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgres://${db_user}:${db_password}@${db_host}:5432/${db_name}
      - REDIS_URL=redis://${redis_host}:6379/0
      - CELERY_BROKER_URL=redis://${redis_host}:6379/1
    command: gunicorn --bind 0.0.0.0:8000 --workers 4 saleor.wsgi:application

  worker:
    environment:
      - DATABASE_URL=postgres://${db_user}:${db_password}@${db_host}:5432/${db_name}
      - REDIS_URL=redis://${redis_host}:6379/0
      - CELERY_BROKER_URL=redis://${redis_host}:6379/1
EOF

# Change ownership
chown -R ec2-user:ec2-user /home/ec2-user/saleor-platform

# Start Saleor using Docker Compose
cd /home/ec2-user/saleor-platform
docker-compose up -d

# Wait for database to be ready and run migrations
sleep 30
docker-compose run --rm api python manage.py migrate
docker-compose run --rm api python manage.py collectstatic --noinput

echo "Saleor installation completed successfully!"
