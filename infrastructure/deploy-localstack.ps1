# LocalStack Deployment Script with Load Balancing
# This script deploys infrastructure to LocalStack and runs the API locally behind a simulated ALB

param(
    [string]$Region = "us-east-1",
    [string]$Endpoint = "http://localhost:4566",
    [string]$ImageName = "dotnetawsapi",
    [int]$InstanceCount = 2
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "LocalStack Deployment with Load Balancing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Common AWS CLI parameters as array for splatting
function Invoke-AwsCli {
    param([string[]]$Arguments)
    $allArgs = @("--endpoint-url", $Endpoint, "--region", $Region) + $Arguments
    aws @allArgs
}

# Step 1: Build the Docker image
Write-Host "`n[1/6] Building Docker image..." -ForegroundColor Yellow
podman build -t "${ImageName}:latest" .
if ($LASTEXITCODE -ne 0) { throw "Failed to build Docker image" }

# Step 2: Create VPC and Networking
Write-Host "`n[2/6] Creating VPC and networking resources..." -ForegroundColor Yellow

# Create VPC
$vpcJson = Invoke-AwsCli @("ec2", "create-vpc", "--cidr-block", "10.0.0.0/16", "--output", "json")
$vpcResult = $vpcJson | ConvertFrom-Json
$vpcId = $vpcResult.Vpc.VpcId
Write-Host "  Created VPC: $vpcId" -ForegroundColor Gray

# Create Internet Gateway
$igwJson = Invoke-AwsCli @("ec2", "create-internet-gateway", "--output", "json")
$igwResult = $igwJson | ConvertFrom-Json
$igwId = $igwResult.InternetGateway.InternetGatewayId
Invoke-AwsCli @("ec2", "attach-internet-gateway", "--vpc-id", $vpcId, "--internet-gateway-id", $igwId) | Out-Null
Write-Host "  Created Internet Gateway: $igwId" -ForegroundColor Gray

# Create subnets in different AZs
$subnet1Json = Invoke-AwsCli @("ec2", "create-subnet", "--vpc-id", $vpcId, "--cidr-block", "10.0.1.0/24", "--availability-zone", "${Region}a", "--output", "json")
$subnet1Result = $subnet1Json | ConvertFrom-Json
$subnet1Id = $subnet1Result.Subnet.SubnetId
Write-Host "  Created Subnet 1: $subnet1Id (${Region}a)" -ForegroundColor Gray

$subnet2Json = Invoke-AwsCli @("ec2", "create-subnet", "--vpc-id", $vpcId, "--cidr-block", "10.0.2.0/24", "--availability-zone", "${Region}b", "--output", "json")
$subnet2Result = $subnet2Json | ConvertFrom-Json
$subnet2Id = $subnet2Result.Subnet.SubnetId
Write-Host "  Created Subnet 2: $subnet2Id (${Region}b)" -ForegroundColor Gray

# Step 3: Create Security Groups
Write-Host "`n[3/6] Creating security groups..." -ForegroundColor Yellow

# ALB Security Group
$albSgJson = Invoke-AwsCli @("ec2", "create-security-group", "--group-name", "alb-sg", "--description", "Security group for ALB", "--vpc-id", $vpcId, "--output", "json")
$albSgResult = $albSgJson | ConvertFrom-Json
$albSgId = $albSgResult.GroupId
Invoke-AwsCli @("ec2", "authorize-security-group-ingress", "--group-id", $albSgId, "--protocol", "tcp", "--port", "80", "--cidr", "0.0.0.0/0") | Out-Null
Write-Host "  Created ALB Security Group: $albSgId" -ForegroundColor Gray

# EC2/ECS Security Group
$ecsSgJson = Invoke-AwsCli @("ec2", "create-security-group", "--group-name", "ecs-tasks-sg", "--description", "Security group for ECS tasks", "--vpc-id", $vpcId, "--output", "json")
$ecsSgResult = $ecsSgJson | ConvertFrom-Json
$ecsSgId = $ecsSgResult.GroupId
Invoke-AwsCli @("ec2", "authorize-security-group-ingress", "--group-id", $ecsSgId, "--protocol", "tcp", "--port", "8080", "--cidr", "0.0.0.0/0") | Out-Null
Write-Host "  Created ECS Security Group: $ecsSgId" -ForegroundColor Gray

# Step 4: Create Application Load Balancer
Write-Host "`n[4/6] Creating Application Load Balancer..." -ForegroundColor Yellow

$albJson = Invoke-AwsCli @("elbv2", "create-load-balancer", "--name", "dotnet-api-alb", "--subnets", $subnet1Id, $subnet2Id, "--security-groups", $albSgId, "--scheme", "internet-facing", "--type", "application", "--output", "json")
$albResult = $albJson | ConvertFrom-Json
$albArn = $albResult.LoadBalancers[0].LoadBalancerArn
$albDns = $albResult.LoadBalancers[0].DNSName
Write-Host "  Created ALB: $albDns" -ForegroundColor Gray
Write-Host "  ALB ARN: $albArn" -ForegroundColor Gray

# Create Target Group
$tgJson = Invoke-AwsCli @("elbv2", "create-target-group", "--name", "dotnet-api-tg", "--protocol", "HTTP", "--port", "8080", "--vpc-id", $vpcId, "--target-type", "ip", "--health-check-path", "/weatherforecast", "--output", "json")
$tgResult = $tgJson | ConvertFrom-Json
$tgArn = $tgResult.TargetGroups[0].TargetGroupArn
Write-Host "  Created Target Group: $tgArn" -ForegroundColor Gray

# Create Listener
$listenerJson = Invoke-AwsCli @("elbv2", "create-listener", "--load-balancer-arn", $albArn, "--protocol", "HTTP", "--port", "80", "--default-actions", "Type=forward,TargetGroupArn=$tgArn", "--output", "json")
Write-Host "  Created Listener on port 80" -ForegroundColor Gray

# Step 5: Run API containers locally (simulating ECS tasks)
Write-Host "`n[5/6] Starting API containers (simulating $InstanceCount ECS tasks)..." -ForegroundColor Yellow

$containerIds = @()
$containerPorts = @()
$basePort = 8081

for ($i = 1; $i -le $InstanceCount; $i++) {
    $port = $basePort + $i - 1
    $containerName = "dotnet-api-instance-$i"
    
    # Stop and remove if exists (ignore errors completely)
    $ErrorActionPreference = "SilentlyContinue"
    podman stop $containerName *>$null
    podman rm $containerName *>$null
    $ErrorActionPreference = "Stop"
    
    # Start container
    $containerId = podman run -d --name $containerName -p "${port}:8080" -e "ASPNETCORE_URLS=http://+:8080" -e "ASPNETCORE_ENVIRONMENT=Production" -e "INSTANCE_ID=$i" "${ImageName}:latest"
    $containerIds += $containerId.Substring(0, 12)
    $containerPorts += $port
    
    # Register target with ALB
    $targetIp = "127.0.0.1"
    Invoke-AwsCli @("elbv2", "register-targets", "--target-group-arn", $tgArn, "--targets", "Id=$targetIp,Port=$port") | Out-Null
    
    Write-Host "  Started instance $i on port $port (Container: $($containerId.Substring(0, 12)))" -ForegroundColor Gray
}

# Step 6: Verify Deployment
Write-Host "`n[6/6] Verifying deployment..." -ForegroundColor Yellow

# Wait for containers to start
Start-Sleep -Seconds 3

# Check health of each instance
$healthyInstances = 0
foreach ($port in $containerPorts) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:${port}/weatherforecast" -TimeoutSec 5
        if ($response) {
            $healthyInstances++
            Write-Host "  Instance on port ${port} - HEALTHY" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Instance on port ${port} - UNHEALTHY" -ForegroundColor Red
    }
}

# Display deployment summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Infrastructure (LocalStack):" -ForegroundColor Cyan
Write-Host "  VPC:              $vpcId"
Write-Host "  Subnets:          $subnet1Id, $subnet2Id"
Write-Host "  ALB DNS:          $albDns"
Write-Host "  ALB ARN:          $albArn"
Write-Host "  Target Group:     $tgArn"
Write-Host ""
Write-Host "Running Containers:" -ForegroundColor Cyan
for ($i = 0; $i -lt $containerIds.Count; $i++) {
    Write-Host "  Instance $($i+1): http://localhost:$($containerPorts[$i]) (Container: $($containerIds[$i]))"
}
Write-Host ""
Write-Host "Healthy Instances:  $healthyInstances / $InstanceCount" -ForegroundColor $(if ($healthyInstances -eq $InstanceCount) { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "Test Individual Instances:" -ForegroundColor Cyan
foreach ($port in $containerPorts) {
    Write-Host "  curl http://localhost:$port/weatherforecast"
}
Write-Host ""
Write-Host "View Load Balancer:" -ForegroundColor Cyan
Write-Host "  aws --endpoint-url=$Endpoint elbv2 describe-load-balancers"
Write-Host ""
Write-Host "View Registered Targets:" -ForegroundColor Cyan
Write-Host "  aws --endpoint-url=$Endpoint elbv2 describe-target-health --target-group-arn `"$tgArn`""

# Save deployment info
$deploymentInfo = @{
    vpcId = $vpcId
    igwId = $igwId
    subnet1Id = $subnet1Id
    subnet2Id = $subnet2Id
    albArn = $albArn
    albDns = $albDns
    tgArn = $tgArn
    albSgId = $albSgId
    ecsSgId = $ecsSgId
    containerIds = $containerIds
    containerPorts = $containerPorts
    instanceCount = $InstanceCount
}
$deploymentInfo | ConvertTo-Json -Depth 5 | Out-File -FilePath ".\infrastructure\deployment-output.json" -Encoding UTF8
Write-Host "`nDeployment info saved to: .\infrastructure\deployment-output.json" -ForegroundColor Gray
