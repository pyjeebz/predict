# Build simplified Lambda package (no ML dependencies needed)

Write-Host "Building simplified Lambda package..." -ForegroundColor Green

# Create temporary directory
if (Test-Path build_simple) {
    Remove-Item -Recurse -Force build_simple
}
New-Item -ItemType Directory -Path build_simple | Out-Null

# Copy the simplified Lambda function (rename to lambda_function.py)
Copy-Item lambda_function_simple.py build_simple/lambda_function.py

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
if (Test-Path lambda_simple.zip) {
    Remove-Item lambda_simple.zip
}

Add-Type -Assembly System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PWD\build_simple", "$PWD\lambda_simple.zip", $compressionLevel, $false)

$size = (Get-Item lambda_simple.zip).Length / 1KB
Write-Host "Lambda package created: lambda_simple.zip" -ForegroundColor Green
Write-Host "Size: $([math]::Round($size, 2)) KB" -ForegroundColor Cyan

# Clean up
Remove-Item -Recurse -Force build_simple

Write-Host "`nThis simplified version uses boto3 (built-in) and statistical analysis" -ForegroundColor Yellow
Write-Host "instead of the ML model. It's ready to deploy directly." -ForegroundColor Yellow
