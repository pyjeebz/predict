# Minimal build - just our code, will use Lambda layers for dependencies

Write-Host "Building minimal Lambda package..." -ForegroundColor Green

# Create temporary directory
if (Test-Path build_minimal) {
    Remove-Item -Recurse -Force build_minimal
}
New-Item -ItemType Directory -Path build_minimal | Out-Null

# Copy only our code files
Copy-Item lambda_function.py build_minimal/
Copy-Item ../ml-model/predictive_scaler.py build_minimal/

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
if (Test-Path lambda_code.zip) {
    Remove-Item lambda_code.zip
}

Add-Type -Assembly System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PWD\build_minimal", "$PWD\lambda_code.zip", $compressionLevel, $false)

$size = (Get-Item lambda_code.zip).Length / 1KB
Write-Host "Lambda package created: lambda_code.zip" -ForegroundColor Green
Write-Host "Size: $([math]::Round($size, 2)) KB" -ForegroundColor Cyan

# Clean up
Remove-Item -Recurse -Force build_minimal

Write-Host "`nNote: This package only includes our code." -ForegroundColor Yellow
Write-Host "You'll need to add a Lambda layer with scikit-learn, numpy, and boto3." -ForegroundColor Yellow
