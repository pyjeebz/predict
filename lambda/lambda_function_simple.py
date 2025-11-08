import json
import boto3
import os
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Simplified predictive scaling using CloudWatch metrics without ML model
    This uses statistical analysis of recent metrics to predict capacity needs
    """
    
    print("Starting predictive scaling execution...")
    
    try:
        cloudwatch = boto3.client('cloudwatch')
        autoscaling = boto3.client('autoscaling')
        
        asg_name = os.environ['ASG_NAME']
        
        # Get current capacity
        asg_response = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
        
        if not asg_response['AutoScalingGroups']:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Auto Scaling Group not found'})
            }
        
        asg = asg_response['AutoScalingGroups'][0]
        current_desired = asg['DesiredCapacity']
        current_min = asg['MinSize']
        current_max = asg['MaxSize']
        
        print(f"Current capacity: desired={current_desired}, min={current_min}, max={current_max}")
        
        # Collect recent CPU metrics (last 30 minutes)
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=30)
        
        cpu_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[{'Name': 'AutoScalingGroupName', 'Value': asg_name}],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,  # 5 minutes
            Statistics=['Average', 'Maximum']
        )
        
        if not cpu_response['Datapoints']:
            print("No recent metrics available")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No metrics available', 'action': 'none'})
            }
        
        # Calculate average and max CPU from recent datapoints
        datapoints = cpu_response['Datapoints']
        avg_cpu = sum(dp['Average'] for dp in datapoints) / len(datapoints)
        max_cpu = max(dp['Maximum'] for dp in datapoints)
        
        print(f"Recent metrics: avg_cpu={avg_cpu:.2f}%, max_cpu={max_cpu:.2f}%")
        
        # Simple scaling logic:
        # - If avg CPU > 85% OR max CPU > 90%, scale up by 2
        # - If avg CPU > 70% OR max CPU > 80%, scale up by 1
        # - If avg CPU < 30% and max < 40%, scale down by 1
        # - Otherwise, maintain current capacity
        
        predicted_capacity = current_desired
        
        if avg_cpu > 85 or max_cpu > 90:
            predicted_capacity = min(current_desired + 2, current_max)
            reason = f"High CPU (avg={avg_cpu:.1f}%, max={max_cpu:.1f}%) - scaling up by 2"
        elif avg_cpu > 70 or max_cpu > 80:
            predicted_capacity = min(current_desired + 1, current_max)
            reason = f"Elevated CPU (avg={avg_cpu:.1f}%, max={max_cpu:.1f}%) - scaling up by 1"
        elif avg_cpu < 30 and max_cpu < 40 and current_desired > current_min:
            predicted_capacity = max(current_desired - 1, current_min)
            reason = f"Low CPU (avg={avg_cpu:.1f}%, max={max_cpu:.1f}%) - scaling down by 1"
        else:
            reason = f"CPU within normal range (avg={avg_cpu:.1f}%, max={max_cpu:.1f}%) - no change"
        
        print(f"Prediction: {predicted_capacity} instances - {reason}")
        
        # Apply scaling if needed
        if predicted_capacity != current_desired:
            print(f"Updating Auto Scaling Group from {current_desired} to {predicted_capacity}")
            
            autoscaling.set_desired_capacity(
                AutoScalingGroupName=asg_name,
                DesiredCapacity=predicted_capacity,
                HonorCooldown=False  # Predictive scaling can override cooldown
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Scaling action taken',
                    'action': 'scaled',
                    'from': current_desired,
                    'to': predicted_capacity,
                    'reason': reason,
                    'avg_cpu': round(avg_cpu, 2),
                    'max_cpu': round(max_cpu, 2)
                })
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No scaling needed',
                    'action': 'none',
                    'capacity': current_desired,
                    'reason': reason,
                    'avg_cpu': round(avg_cpu, 2),
                    'max_cpu': round(max_cpu, 2)
                })
            }
            
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
