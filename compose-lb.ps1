# Docker Compose Load Balancer Management Script

param(
    [Parameter(Position=0)]
    [ValidateSet("up", "down", "scale", "status", "logs", "test")]
    [string]$Action = "status",
    
    [int]$Instances = 3
)

$composeFile = "docker-compose.yml"

switch ($Action) {
    "up" {
        Write-Host "Starting load-balanced API with $Instances instances..." -ForegroundColor Cyan
        podman compose -f $composeFile up -d --scale api=$Instances --build
        
        Start-Sleep -Seconds 5
        Write-Host "`nServices running:" -ForegroundColor Green
        podman compose -f $composeFile ps
        
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Load Balancer Ready!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "API Endpoint:  http://localhost/weatherforecast"
        Write-Host "LB Health:     http://localhost/health"
        Write-Host "Instances:     $Instances"
    }
    
    "down" {
        Write-Host "Stopping all services..." -ForegroundColor Yellow
        podman compose -f $composeFile down
        Write-Host "All services stopped." -ForegroundColor Green
    }
    
    "scale" {
        Write-Host "Scaling API to $Instances instances..." -ForegroundColor Cyan
        podman compose -f $composeFile up -d --scale api=$Instances --no-recreate
        
        Start-Sleep -Seconds 3
        podman compose -f $composeFile ps
    }
    
    "status" {
        Write-Host "Current services:" -ForegroundColor Cyan
        podman compose -f $composeFile ps
    }
    
    "logs" {
        podman compose -f $composeFile logs -f
    }
    
    "test" {
        Write-Host "Testing load balancer (5 requests)..." -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 1; $i -le 5; $i++) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost/weatherforecast" -UseBasicParsing
                $upstream = $response.Headers["X-Upstream-Server"]
                Write-Host "Request $i - Upstream: $upstream - Status: $($response.StatusCode)" -ForegroundColor Green
            } catch {
                Write-Host "Request $i - FAILED: $($_.Exception.Message)" -ForegroundColor Red
            }
            Start-Sleep -Milliseconds 500
        }
        
        Write-Host "`nIf you see different upstream IPs, load balancing is working!" -ForegroundColor Cyan
    }
}
