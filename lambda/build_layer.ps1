# Build optimized Lambda Layer with scikit-learn using Docker

Write-Host "Building optimized Lambda Layer with scikit-learn..." -ForegroundColor Green

# Create temporary directory
if (Test-Path layer-build) {
    Remove-Item -Recurse -Force layer-build
}
New-Item -ItemType Directory -Path layer-build/python | Out-Null

# Create requirements file for layer
Set-Content -Path layer-build/requirements.txt -Value @"
numpy
scikit-learn
"@

# Build using Docker with Python 3.11 and optimize for size
Write-Host "Installing dependencies in Linux container (optimized)..." -ForegroundColor Yellow
docker run --rm -v "${PWD}/layer-build:/var/task" python:3.11-slim bash -c "pip install --no-cache-dir -r /var/task/requirements.txt -t /var/task/python/ && cd /var/task/python && find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true && find . -type f -name '*.pyc' -delete && find . -type f -name '*.pyo' -delete"

Write-Host "Stripping unnecessary files to reduce size..." -ForegroundColor Yellow

# Create ZIP package for layer
Write-Host "Creating layer ZIP package..." -ForegroundColor Yellow
if (Test-Path sklearn-layer.zip) {
    Remove-Item sklearn-layer.zip
}

# Remove requirements.txt from build directory before zipping
Remove-Item layer-build/requirements.txt -ErrorAction SilentlyContinue

# Compress only the python directory
Add-Type -Assembly System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PWD\layer-build", "$PWD\sklearn-layer.zip", $compressionLevel, $false)

$size = (Get-Item sklearn-layer.zip).Length / 1MB
Write-Host "Optimized Lambda layer created: sklearn-layer.zip" -ForegroundColor Green
Write-Host "Size: $([math]::Round($size, 2)) MB" -ForegroundColor Cyan

# Clean up
Remove-Item -Recurse -Force layer-build

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Upload to S3: aws s3 cp sklearn-layer.zip s3://saleor-predictive-scaling-ml-data-976193245014/layers/" -ForegroundColor Cyan
Write-Host "2. Publish layer: aws lambda publish-layer-version --layer-name sklearn-numpy --content S3Bucket=saleor-predictive-scaling-ml-data-976193245014,S3Key=layers/sklearn-layer.zip --compatible-runtimes python3.11" -ForegroundColor Cyan
Write-Host "3. Add layer to function: aws lambda update-function-configuration --function-name <name> --layers <layer-arn>" -ForegroundColor Cyan
