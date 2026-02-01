# Cleanup LocalStack Deployment
# This script removes all resources created by the deployment

param(
    [string]$Region = "us-east-1",
    [string]$Endpoint = "http://localhost:4566"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Cleaning up LocalStack Deployment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

function Invoke-AwsCli {
    param([string[]]$Arguments)
    $allArgs = @("--endpoint-url", $Endpoint, "--region", $Region) + $Arguments
    aws @allArgs 2>$null
}

# Load deployment info if exists
$deploymentFile = ".\infrastructure\deployment-output.json"
if (Test-Path $deploymentFile) {
    $deployment = Get-Content $deploymentFile | ConvertFrom-Json
    
    # Stop and remove containers
    Write-Host "`nStopping containers..." -ForegroundColor Gray
    for ($i = 1; $i -le $deployment.instanceCount; $i++) {
        $containerName = "dotnet-api-instance-$i"
        podman stop $containerName 2>$null
        podman rm $containerName 2>$null
        Write-Host "  Removed container: $containerName" -ForegroundColor Gray
    }
    
    # Delete Load Balancer
    Write-Host "`nDeleting Load Balancer..." -ForegroundColor Gray
    Invoke-AwsCli @("elbv2", "delete-load-balancer", "--load-balancer-arn", $deployment.albArn)
    
    # Delete Target Group
    Write-Host "Deleting Target Group..." -ForegroundColor Gray
    Invoke-AwsCli @("elbv2", "delete-target-group", "--target-group-arn", $deployment.tgArn)
    
    # Delete Security Groups
    Write-Host "Deleting Security Groups..." -ForegroundColor Gray
    Invoke-AwsCli @("ec2", "delete-security-group", "--group-id", $deployment.ecsSgId)
    Invoke-AwsCli @("ec2", "delete-security-group", "--group-id", $deployment.albSgId)
    
    # Detach Internet Gateway
    Write-Host "Detaching Internet Gateway..." -ForegroundColor Gray
    Invoke-AwsCli @("ec2", "detach-internet-gateway", "--internet-gateway-id", $deployment.igwId, "--vpc-id", $deployment.vpcId)
    Invoke-AwsCli @("ec2", "delete-internet-gateway", "--internet-gateway-id", $deployment.igwId)
    
    # Delete Subnets
    Write-Host "Deleting Subnets..." -ForegroundColor Gray
    Invoke-AwsCli @("ec2", "delete-subnet", "--subnet-id", $deployment.subnet1Id)
    Invoke-AwsCli @("ec2", "delete-subnet", "--subnet-id", $deployment.subnet2Id)
    
    # Delete VPC
    Write-Host "Deleting VPC..." -ForegroundColor Gray
    Invoke-AwsCli @("ec2", "delete-vpc", "--vpc-id", $deployment.vpcId)
    
    # Remove deployment file
    Remove-Item $deploymentFile -Force
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Cleanup complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "No deployment file found. Manual cleanup may be required." -ForegroundColor Yellow
    Write-Host "Checking for any running API containers..." -ForegroundColor Gray
    
    # Try to clean up any leftover containers
    for ($i = 1; $i -le 5; $i++) {
        $containerName = "dotnet-api-instance-$i"
        podman stop $containerName 2>$null
        podman rm $containerName 2>$null
    }
}
