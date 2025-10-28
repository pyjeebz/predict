#!/bin/bash
# Script to run different Locust load test scenarios

# Configuration
HOST="${1:-http://localhost:8000}"
SCENARIO="${2:-baseline}"

echo "Starting Locust load test..."
echo "Target: $HOST"
echo "Scenario: $SCENARIO"

case $SCENARIO in
    baseline)
        echo "Running baseline traffic test..."
        locust -f locustfile.py --host=$HOST --users=20 --spawn-rate=2 --run-time=10m --headless
        ;;
    
    surge)
        echo "Running traffic surge test..."
        locust -f locustfile.py -f traffic_patterns.py --host=$HOST --shape=TrafficSurgeShape --headless
        ;;
    
    sinusoidal)
        echo "Running sinusoidal traffic pattern test..."
        locust -f locustfile.py -f traffic_patterns.py --host=$HOST --shape=SinusoidalTrafficShape --headless
        ;;
    
    step)
        echo "Running step load test..."
        locust -f locustfile.py -f traffic_patterns.py --host=$HOST --shape=StepLoadShape --headless
        ;;
    
    flash-sale)
        echo "Running flash sale simulation..."
        locust -f locustfile.py -f traffic_patterns.py --host=$HOST --shape=FlashSaleShape --headless
        ;;
    
    web)
        echo "Starting Locust web UI..."
        echo "Access the UI at http://localhost:8089"
        locust -f locustfile.py --host=$HOST
        ;;
    
    *)
        echo "Unknown scenario: $SCENARIO"
        echo "Available scenarios: baseline, surge, sinusoidal, step, flash-sale, web"
        exit 1
        ;;
esac
