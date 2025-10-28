# Script to build and package Lambda function for Windows

Write-Host "Building Lambda deployment package..." -ForegroundColor Green

# Create temporary directory
if (Test-Path build) {
    Remove-Item -Recurse -Force build
}
New-Item -ItemType Directory -Path build | Out-Null

# Copy Lambda function
Copy-Item lambda_function.py build/

# Copy predictive scaler module
Copy-Item ../ml-model/predictive_scaler.py build/

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t build/

# Create deployment package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
if (Test-Path predictive_scaling.zip) {
    Remove-Item predictive_scaling.zip
}

Add-Type -Assembly System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PWD\build", "$PWD\predictive_scaling.zip", $compressionLevel, $false)

Write-Host "Lambda package created: predictive_scaling.zip" -ForegroundColor Green
$size = (Get-Item predictive_scaling.zip).Length / 1MB
Write-Host ("Size: {0:N2} MB" -f $size) -ForegroundColor Cyan
