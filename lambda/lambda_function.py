import json
import os
import sys

# Add the current directory to the path for imports
sys.path.insert(0, os.path.dirname(__file__))

from predictive_scaler import PredictiveScaler

def lambda_handler(event, context):
    """
    AWS Lambda handler for predictive scaling
    This function is triggered every 5 minutes by EventBridge
    """
    
    print("Starting predictive scaling execution...")
    
    try:
        # Initialize the scaler
        scaler = PredictiveScaler()
        
        # Get current capacity
        current_capacity = scaler.get_current_capacity()
        print(f"Current capacity: {current_capacity}")
        
        # Predict required capacity
        predicted_capacity = scaler.predict_capacity()
        
        if predicted_capacity is None:
            print("No prediction available - model not trained yet")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No model available for prediction',
                    'action': 'none'
                })
            }
        
        print(f"Predicted capacity: {predicted_capacity}")
        
        # Determine if scaling is needed
        current_desired = current_capacity['desired']
        
        # Only scale if difference is significant (at least 1 instance)
        if abs(predicted_capacity - current_desired) >= 1:
            print(f"Scaling from {current_desired} to {predicted_capacity} instances")
            
            success = scaler.scale_autoscaling_group(predicted_capacity)
            
            if success:
                # Publish to SNS
                sns_message = {
                    'timestamp': context.aws_request_id,
                    'current_capacity': current_desired,
                    'predicted_capacity': predicted_capacity,
                    'action': 'scaled'
                }
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Successfully scaled Auto Scaling Group',
                        'current_capacity': current_desired,
                        'new_capacity': predicted_capacity,
                        'action': 'scaled'
                    })
                }
            else:
                return {
                    'statusCode': 500,
                    'body': json.dumps({
                        'message': 'Failed to scale Auto Scaling Group',
                        'action': 'error'
                    })
                }
        else:
            print(f"No scaling needed - current: {current_desired}, predicted: {predicted_capacity}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No scaling needed',
                    'current_capacity': current_desired,
                    'predicted_capacity': predicted_capacity,
                    'action': 'none'
                })
            }
            
    except Exception as e:
        print(f"Error in predictive scaling: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error: {str(e)}',
                'action': 'error'
            })
        }

# For local testing
if __name__ == "__main__":
    # Mock event and context for testing
    class MockContext:
        aws_request_id = "test-request-id"
    
    result = lambda_handler({}, MockContext())
    print(json.dumps(result, indent=2))
