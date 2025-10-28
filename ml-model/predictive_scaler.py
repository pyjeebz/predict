import boto3
import json
import pickle
import numpy as np
from datetime import datetime, timedelta
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
import os

class PredictiveScaler:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.autoscaling = boto3.client('autoscaling')
        self.s3 = boto3.client('s3')
        
        self.asg_name = os.environ['ASG_NAME']
        self.s3_bucket = os.environ['S3_BUCKET']
        self.min_instances = int(os.environ.get('MIN_INSTANCES', 1))
        self.max_instances = int(os.environ.get('MAX_INSTANCES', 10))
        
        self.model = None
        self.scaler = None
        
    def collect_metrics(self, hours_back=24):
        """Collect CloudWatch metrics for training/prediction"""
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours_back)
        
        metrics_to_collect = [
            {
                'namespace': 'AWS/ApplicationELB',
                'metric_name': 'RequestCount',
                'stat': 'Sum'
            },
            {
                'namespace': 'AWS/ApplicationELB',
                'metric_name': 'TargetResponseTime',
                'stat': 'Average'
            },
            {
                'namespace': 'AWS/EC2',
                'metric_name': 'CPUUtilization',
                'stat': 'Average'
            },
            {
                'namespace': 'AWS/AutoScaling',
                'metric_name': 'GroupDesiredCapacity',
                'stat': 'Average'
            }
        ]
        
        all_metrics = {}
        
        for metric_info in metrics_to_collect:
            response = self.cloudwatch.get_metric_statistics(
                Namespace=metric_info['namespace'],
                MetricName=metric_info['metric_name'],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,  # 5 minutes
                Statistics=[metric_info['stat']]
            )
            
            datapoints = sorted(response['Datapoints'], key=lambda x: x['Timestamp'])
            all_metrics[metric_info['metric_name']] = datapoints
            
        return all_metrics
    
    def prepare_training_data(self, metrics_data):
        """Prepare data for ML model training"""
        # Extract features and target
        timestamps = []
        features = []
        targets = []
        
        request_counts = metrics_data.get('RequestCount', [])
        response_times = metrics_data.get('TargetResponseTime', [])
        cpu_utilizations = metrics_data.get('CPUUtilization', [])
        desired_capacities = metrics_data.get('GroupDesiredCapacity', [])
        
        # Align all metrics by timestamp
        for i in range(len(request_counts)):
            if i < len(response_times) and i < len(cpu_utilizations) and i < len(desired_capacities):
                timestamp = request_counts[i]['Timestamp']
                
                # Features: request count, response time, CPU, hour of day, day of week
                hour = timestamp.hour
                day_of_week = timestamp.weekday()
                
                feature_vector = [
                    request_counts[i].get('Sum', 0),
                    response_times[i].get('Average', 0),
                    cpu_utilizations[i].get('Average', 0),
                    hour,
                    day_of_week
                ]
                
                features.append(feature_vector)
                
                # Target: desired capacity for next period (5 min ahead)
                if i + 1 < len(desired_capacities):
                    targets.append(desired_capacities[i + 1].get('Average', 1))
                else:
                    targets.append(desired_capacities[i].get('Average', 1))
        
        return np.array(features), np.array(targets)
    
    def train_model(self, features, targets):
        """Train the Random Forest model"""
        if len(features) < 10:
            print("Not enough data to train model")
            return False
            
        # Normalize features
        self.scaler = StandardScaler()
        features_scaled = self.scaler.fit_transform(features)
        
        # Train Random Forest
        self.model = RandomForestRegressor(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            n_jobs=-1
        )
        
        self.model.fit(features_scaled, targets)
        
        # Save model to S3
        self.save_model()
        
        return True
    
    def save_model(self):
        """Save model and scaler to S3"""
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Pickle the model
        model_bytes = pickle.dumps(model_data)
        
        # Upload to S3
        self.s3.put_object(
            Bucket=self.s3_bucket,
            Key='models/predictive_scaling_model.pkl',
            Body=model_bytes
        )
        
        print("Model saved to S3")
    
    def load_model(self):
        """Load model from S3"""
        try:
            response = self.s3.get_object(
                Bucket=self.s3_bucket,
                Key='models/predictive_scaling_model.pkl'
            )
            
            model_data = pickle.loads(response['Body'].read())
            self.model = model_data['model']
            self.scaler = model_data['scaler']
            
            print("Model loaded from S3")
            return True
        except Exception as e:
            print(f"Could not load model: {e}")
            return False
    
    def predict_capacity(self):
        """Predict required capacity for next period"""
        # Load model if not already loaded
        if self.model is None:
            if not self.load_model():
                print("No model available, using reactive scaling")
                return None
        
        # Get current metrics
        current_metrics = self.collect_metrics(hours_back=1)
        
        # Get latest values
        latest_request_count = current_metrics['RequestCount'][-1].get('Sum', 0) if current_metrics['RequestCount'] else 0
        latest_response_time = current_metrics['TargetResponseTime'][-1].get('Average', 0) if current_metrics['TargetResponseTime'] else 0
        latest_cpu = current_metrics['CPUUtilization'][-1].get('Average', 0) if current_metrics['CPUUtilization'] else 0
        
        now = datetime.utcnow()
        
        # Create feature vector
        feature_vector = np.array([[
            latest_request_count,
            latest_response_time,
            latest_cpu,
            now.hour,
            now.weekday()
        ]])
        
        # Scale features
        feature_scaled = self.scaler.transform(feature_vector)
        
        # Predict
        predicted_capacity = self.model.predict(feature_scaled)[0]
        
        # Round and constrain
        predicted_capacity = int(round(predicted_capacity))
        predicted_capacity = max(self.min_instances, min(self.max_instances, predicted_capacity))
        
        return predicted_capacity
    
    def scale_autoscaling_group(self, desired_capacity):
        """Scale the Auto Scaling Group"""
        try:
            self.autoscaling.set_desired_capacity(
                AutoScalingGroupName=self.asg_name,
                DesiredCapacity=desired_capacity,
                HonorCooldown=False
            )
            
            print(f"Scaled Auto Scaling Group to {desired_capacity} instances")
            return True
        except Exception as e:
            print(f"Error scaling Auto Scaling Group: {e}")
            return False
    
    def get_current_capacity(self):
        """Get current ASG capacity"""
        try:
            response = self.autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.asg_name]
            )
            
            if response['AutoScalingGroups']:
                asg = response['AutoScalingGroups'][0]
                return {
                    'desired': asg['DesiredCapacity'],
                    'current': len(asg['Instances']),
                    'min': asg['MinSize'],
                    'max': asg['MaxSize']
                }
        except Exception as e:
            print(f"Error getting ASG capacity: {e}")
            
        return None
