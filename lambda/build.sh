#!/bin/bash
# Script to build and package Lambda function

set -e

echo "Building Lambda deployment package..."

# Create temporary directory
rm -rf build
mkdir -p build

# Copy Lambda function
cp lambda_function.py build/

# Copy predictive scaler module
cp ../ml-model/predictive_scaler.py build/

# Install dependencies
pip install -r requirements.txt -t build/

# Create deployment package
cd build
zip -r ../predictive_scaling.zip .
cd ..

echo "Lambda package created: predictive_scaling.zip"
echo "Size: $(du -h predictive_scaling.zip | cut -f1)"
