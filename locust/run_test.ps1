# Script to run different Locust load test scenarios on Windows

param(
    [string]$TargetHost = "http://localhost:8000",
    [string]$Scenario = "baseline"
)

Write-Host "Starting Locust load test..." -ForegroundColor Green
Write-Host "Target: $TargetHost" -ForegroundColor Cyan
Write-Host "Scenario: $Scenario" -ForegroundColor Cyan
Write-Host ""

switch ($Scenario) {
    "baseline" {
        Write-Host "Running baseline traffic test..." -ForegroundColor Yellow
        locust -f locustfile.py --host=$TargetHost --users=20 --spawn-rate=2 --run-time=10m --headless
    }
    
    "surge" {
        Write-Host "Running traffic surge test..." -ForegroundColor Yellow
        locust -f locustfile.py -f traffic_patterns.py --host=$TargetHost --shape=TrafficSurgeShape --headless
    }
    
    "sinusoidal" {
        Write-Host "Running sinusoidal traffic pattern test..." -ForegroundColor Yellow
        locust -f locustfile.py -f traffic_patterns.py --host=$TargetHost --shape=SinusoidalTrafficShape --headless
    }
    
    "step" {
        Write-Host "Running step load test..." -ForegroundColor Yellow
        locust -f locustfile.py -f traffic_patterns.py --host=$TargetHost --shape=StepLoadShape --headless
    }
    
    "flash-sale" {
        Write-Host "Running flash sale simulation..." -ForegroundColor Yellow
        locust -f locustfile.py -f traffic_patterns.py --host=$TargetHost --shape=FlashSaleShape --headless
    }
    
    "web" {
        Write-Host "Starting Locust web UI..." -ForegroundColor Yellow
        Write-Host "Access the UI at http://localhost:8089" -ForegroundColor Cyan
        locust -f locustfile.py --host=$TargetHost
    }
    
    default {
        Write-Host "Unknown scenario: $Scenario" -ForegroundColor Red
        Write-Host "Available scenarios: baseline, surge, sinusoidal, step, flash-sale, web" -ForegroundColor Yellow
        exit 1
    }
}
