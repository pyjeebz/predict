# Script to build Lambda package using Docker for Linux compatibility

Write-Host "Building Lambda deployment package using Docker..." -ForegroundColor Green

# Create temporary directory
if (Test-Path build) {
    Remove-Item -Recurse -Force build
}
New-Item -ItemType Directory -Path build | Out-Null

# Copy Lambda function files
Copy-Item lambda_function.py build/
Copy-Item ../ml-model/predictive_scaler.py build/
Copy-Item requirements.txt build/

# Build using Docker with Python 3.11 on Linux
Write-Host "Installing dependencies in Linux container..." -ForegroundColor Yellow
docker run --rm -v "${PWD}/build:/var/task" python:3.11-slim bash -c "pip install -r /var/task/requirements.txt -t /var/task/"

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
if (Test-Path predictive_scaling.zip) {
    Remove-Item predictive_scaling.zip
}

# Compress the build directory
Add-Type -Assembly System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PWD\build", "$PWD\predictive_scaling.zip", $compressionLevel, $false)

$size = (Get-Item predictive_scaling.zip).Length / 1MB
Write-Host "Lambda package created: predictive_scaling.zip" -ForegroundColor Green
Write-Host "Size: $([math]::Round($size, 2)) MB" -ForegroundColor Cyan

# Clean up
Remove-Item -Recurse -Force build
