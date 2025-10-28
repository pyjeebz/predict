#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting user data script at $(date) ==="

# -----------------------------
# System setup
# -----------------------------
echo "Updating system packages..."
yum update -y

echo "Installing Python, pip, and dependencies..."
yum install -y python3 python3-pip gcc python3-devel wget

# -----------------------------
# CloudWatch Agent setup
# -----------------------------
echo "Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "metrics": {
    "namespace": "SaleorPredictiveScaling",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# -----------------------------
# Flask App setup
# -----------------------------
echo "Creating application directory..."
mkdir -p /opt/app
cd /opt/app

# Create Flask app
cat > /opt/app/app.py <<'PYEOF'
#!/usr/bin/env python3
import time, random
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({'service': 'Saleor Predictive Scaling Demo', 'status': 'running', 'version': '1.0'})

@app.route('/graphql/', methods=['GET', 'POST'])
def graphql():
    time.sleep(random.uniform(0.01, 0.05))
    return jsonify({'data': {'shop': {'name': 'Demo Store'}}})

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/products')
def products():
    time.sleep(random.uniform(0.02, 0.1))
    products = [{'id': i, 'name': f'Product {i}', 'price': random.randint(10, 1000)} for i in range(1, 21)]
    return jsonify({'products': products})

@app.route('/cart', methods=['GET', 'POST'])
def cart():
    time.sleep(random.uniform(0.03, 0.08))
    if request.method == 'POST':
        return jsonify({'status': 'added', 'cart_id': random.randint(1000, 9999)})
    return jsonify({'items': [], 'total': 0})

@app.route('/checkout', methods=['POST'])
def checkout():
    time.sleep(random.uniform(0.1, 0.3))
    return jsonify({'status': 'success', 'order_id': random.randint(10000, 99999)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
PYEOF

chmod +x /opt/app/app.py

# Create requirements file
cat > /opt/app/requirements.txt <<'EOF'
flask>=3.0.0
gunicorn>=21.2.0
EOF

echo "Installing Python dependencies..."
pip3 install --upgrade pip
pip3 install -r requirements.txt --no-cache-dir

# Verify Flask installation
python3 -c "import flask; print(f'Flask {flask.__version__} installed successfully')" || echo "ERROR: Flask import failed!"

# -----------------------------
# Gunicorn systemd service
# -----------------------------
echo "Creating systemd service for Gunicorn..."

cat > /etc/systemd/system/flask-app.service <<'EOF'
[Unit]
Description=Flask Demo Application (Gunicorn)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Start the service
echo "Starting Flask application with Gunicorn..."
systemctl daemon-reload
systemctl enable flask-app
systemctl start flask-app

# Wait and verify service is running
sleep 5
systemctl status flask-app --no-pager

# Test local endpoint
echo "Testing local Flask endpoint..."
curl -s http://localhost:8000/ || echo "WARNING: Local Flask test failed!"

echo "=== User data script completed at $(date) ==="
echo "Application should be running on port 8000"
