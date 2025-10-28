import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import seaborn as sns
from predictive_scaler import PredictiveScaler

def train_model_standalone():
    """Standalone script to train the ML model"""
    
    print("Initializing Predictive Scaler...")
    scaler = PredictiveScaler()
    
    print("Collecting historical metrics (last 7 days)...")
    metrics = scaler.collect_metrics(hours_back=168)  # 7 days
    
    print("Preparing training data...")
    features, targets = scaler.prepare_training_data(metrics)
    
    print(f"Training data shape: Features: {features.shape}, Targets: {targets.shape}")
    
    if len(features) < 10:
        print("ERROR: Not enough data for training. Need at least 10 data points.")
        print("Please run the system for a while to collect metrics first.")
        return
    
    print("Training model...")
    success = scaler.train_model(features, targets)
    
    if success:
        print("Model trained successfully!")
        
        # Simple validation
        predictions = scaler.model.predict(scaler.scaler.transform(features))
        mse = np.mean((predictions - targets) ** 2)
        rmse = np.sqrt(mse)
        
        print(f"Training RMSE: {rmse:.2f}")
        print(f"Mean target capacity: {np.mean(targets):.2f}")
        
        # Plot actual vs predicted
        plt.figure(figsize=(12, 6))
        plt.plot(targets[:100], label='Actual', marker='o')
        plt.plot(predictions[:100], label='Predicted', marker='x')
        plt.xlabel('Time Period')
        plt.ylabel('Desired Capacity')
        plt.title('Actual vs Predicted Capacity (First 100 Points)')
        plt.legend()
        plt.grid(True)
        plt.savefig('model_validation.png')
        print("Validation plot saved as 'model_validation.png'")
        
    else:
        print("Model training failed!")

if __name__ == "__main__":
    train_model_standalone()
