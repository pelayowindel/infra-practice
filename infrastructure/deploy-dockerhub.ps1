# LocalStack ECS Deployment with Docker Hub Image
# This script deploys using ECS with an image from Docker Hub

param(
    [Parameter(Mandatory=$true)]
    [string]$DockerHubImage,  # e.g., "username/dotnetawsapi:latest"
    
    [string]$Region = "us-east-1",
    [string]$Endpoint = "http://localhost:4566",
    [string]$ClusterName = "dotnet-api-cluster",
    [string]$ServiceName = "dotnet-api-service",
    [int]$DesiredCount = 2
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "LocalStack ECS Deployment (Docker Hub)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Image: $DockerHubImage" -ForegroundColor Gray

function Invoke-AwsCli {
    param([string[]]$Arguments)
    $allArgs = @("--endpoint-url", $Endpoint, "--region", $Region) + $Arguments
    aws @allArgs
}

# Step 1: Create VPC and Networking
Write-Host "`n[1/6] Creating VPC and networking resources..." -ForegroundColor Yellow

$vpcJson = Invoke-AwsCli @("ec2", "create-vpc", "--cidr-block", "10.0.0.0/16", "--output", "json")
$vpcResult = $vpcJson | ConvertFrom-Json
$vpcId = $vpcResult.Vpc.VpcId
Write-Host "  Created VPC: $vpcId" -ForegroundColor Gray

$igwJson = Invoke-AwsCli @("ec2", "create-internet-gateway", "--output", "json")
$igwResult = $igwJson | ConvertFrom-Json
$igwId = $igwResult.InternetGateway.InternetGatewayId
Invoke-AwsCli @("ec2", "attach-internet-gateway", "--vpc-id", $vpcId, "--internet-gateway-id", $igwId) | Out-Null
Write-Host "  Created Internet Gateway: $igwId" -ForegroundColor Gray

$subnet1Json = Invoke-AwsCli @("ec2", "create-subnet", "--vpc-id", $vpcId, "--cidr-block", "10.0.1.0/24", "--availability-zone", "${Region}a", "--output", "json")
$subnet1Result = $subnet1Json | ConvertFrom-Json
$subnet1Id = $subnet1Result.Subnet.SubnetId
Write-Host "  Created Subnet 1: $subnet1Id" -ForegroundColor Gray

$subnet2Json = Invoke-AwsCli @("ec2", "create-subnet", "--vpc-id", $vpcId, "--cidr-block", "10.0.2.0/24", "--availability-zone", "${Region}b", "--output", "json")
$subnet2Result = $subnet2Json | ConvertFrom-Json
$subnet2Id = $subnet2Result.Subnet.SubnetId
Write-Host "  Created Subnet 2: $subnet2Id" -ForegroundColor Gray

# Step 2: Create Security Groups
Write-Host "`n[2/6] Creating security groups..." -ForegroundColor Yellow

$albSgJson = Invoke-AwsCli @("ec2", "create-security-group", "--group-name", "alb-sg-dockerhub", "--description", "ALB Security Group", "--vpc-id", $vpcId, "--output", "json")
$albSgResult = $albSgJson | ConvertFrom-Json
$albSgId = $albSgResult.GroupId
Invoke-AwsCli @("ec2", "authorize-security-group-ingress", "--group-id", $albSgId, "--protocol", "tcp", "--port", "80", "--cidr", "0.0.0.0/0") | Out-Null
Write-Host "  Created ALB Security Group: $albSgId" -ForegroundColor Gray

$ecsSgJson = Invoke-AwsCli @("ec2", "create-security-group", "--group-name", "ecs-sg-dockerhub", "--description", "ECS Security Group", "--vpc-id", $vpcId, "--output", "json")
$ecsSgResult = $ecsSgJson | ConvertFrom-Json
$ecsSgId = $ecsSgResult.GroupId
Invoke-AwsCli @("ec2", "authorize-security-group-ingress", "--group-id", $ecsSgId, "--protocol", "tcp", "--port", "8080", "--cidr", "0.0.0.0/0") | Out-Null
Write-Host "  Created ECS Security Group: $ecsSgId" -ForegroundColor Gray

# Step 3: Create Application Load Balancer
Write-Host "`n[3/6] Creating Application Load Balancer..." -ForegroundColor Yellow

$albJson = Invoke-AwsCli @("elbv2", "create-load-balancer", "--name", "dotnet-alb-dh", "--subnets", $subnet1Id, $subnet2Id, "--security-groups", $albSgId, "--scheme", "internet-facing", "--type", "application", "--output", "json")
$albResult = $albJson | ConvertFrom-Json
$albArn = $albResult.LoadBalancers[0].LoadBalancerArn
$albDns = $albResult.LoadBalancers[0].DNSName
Write-Host "  Created ALB: $albDns" -ForegroundColor Gray

$tgJson = Invoke-AwsCli @("elbv2", "create-target-group", "--name", "dotnet-tg-dh", "--protocol", "HTTP", "--port", "8080", "--vpc-id", $vpcId, "--target-type", "ip", "--health-check-path", "/weatherforecast", "--output", "json")
$tgResult = $tgJson | ConvertFrom-Json
$tgArn = $tgResult.TargetGroups[0].TargetGroupArn
Write-Host "  Created Target Group: $tgArn" -ForegroundColor Gray

Invoke-AwsCli @("elbv2", "create-listener", "--load-balancer-arn", $albArn, "--protocol", "HTTP", "--port", "80", "--default-actions", "Type=forward,TargetGroupArn=$tgArn") | Out-Null
Write-Host "  Created Listener on port 80" -ForegroundColor Gray

# Step 4: Create ECS Cluster
Write-Host "`n[4/6] Creating ECS cluster..." -ForegroundColor Yellow
Invoke-AwsCli @("ecs", "create-cluster", "--cluster-name", $ClusterName) | Out-Null
Write-Host "  Created cluster: $ClusterName" -ForegroundColor Gray

# Step 5: Register Task Definition
Write-Host "`n[5/6] Registering task definition..." -ForegroundColor Yellow

# Create log group
$ErrorActionPreference = "SilentlyContinue"
Invoke-AwsCli @("logs", "create-log-group", "--log-group-name", "/ecs/dotnet-api-dh") | Out-Null
$ErrorActionPreference = "Stop"

$taskDef = @{
    family = "dotnet-api-task-dh"
    networkMode = "awsvpc"
    requiresCompatibilities = @("FARGATE")
    cpu = "256"
    memory = "512"
    containerDefinitions = @(
        @{
            name = "dotnet-api"
            image = $DockerHubImage
            essential = $true
            portMappings = @(
                @{
                    containerPort = 8080
                    hostPort = 8080
                    protocol = "tcp"
                }
            )
            environment = @(
                @{ name = "ASPNETCORE_URLS"; value = "http://+:8080" }
                @{ name = "ASPNETCORE_ENVIRONMENT"; value = "Production" }
            )
            logConfiguration = @{
                logDriver = "awslogs"
                options = @{
                    "awslogs-group" = "/ecs/dotnet-api-dh"
                    "awslogs-region" = $Region
                    "awslogs-stream-prefix" = "ecs"
                }
            }
        }
    )
}

$taskDefJson = $taskDef | ConvertTo-Json -Depth 10
$taskDefFile = ".\infrastructure\task-definition-dockerhub.json"
$taskDefJson | Out-File -FilePath $taskDefFile -Encoding UTF8

Invoke-AwsCli @("ecs", "register-task-definition", "--cli-input-json", "file://$taskDefFile") | Out-Null
Write-Host "  Registered task definition with image: $DockerHubImage" -ForegroundColor Gray

# Step 6: Create ECS Service
Write-Host "`n[6/6] Creating ECS service..." -ForegroundColor Yellow

$serviceDef = @{
    cluster = $ClusterName
    serviceName = $ServiceName
    taskDefinition = "dotnet-api-task-dh"
    desiredCount = $DesiredCount
    launchType = "FARGATE"
    networkConfiguration = @{
        awsvpcConfiguration = @{
            subnets = @($subnet1Id, $subnet2Id)
            securityGroups = @($ecsSgId)
            assignPublicIp = "ENABLED"
        }
    }
    loadBalancers = @(
        @{
            targetGroupArn = $tgArn
            containerName = "dotnet-api"
            containerPort = 8080
        }
    )
}

$serviceDefJson = $serviceDef | ConvertTo-Json -Depth 10
$serviceDefFile = ".\infrastructure\service-definition-dockerhub.json"
$serviceDefJson | Out-File -FilePath $serviceDefFile -Encoding UTF8

Invoke-AwsCli @("ecs", "create-service", "--cli-input-json", "file://$serviceDefFile") | Out-Null
Write-Host "  Created ECS service: $ServiceName with $DesiredCount tasks" -ForegroundColor Gray

# Display summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "ECS Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Docker Hub Image:   $DockerHubImage" -ForegroundColor Cyan
Write-Host "ECS Cluster:        $ClusterName" -ForegroundColor Cyan
Write-Host "ECS Service:        $ServiceName" -ForegroundColor Cyan
Write-Host "Desired Tasks:      $DesiredCount" -ForegroundColor Cyan
Write-Host "ALB DNS:            $albDns" -ForegroundColor Cyan
Write-Host ""
Write-Host "View ECS Service:" -ForegroundColor Yellow
Write-Host "  aws --endpoint-url=$Endpoint ecs describe-services --cluster $ClusterName --services $ServiceName"
Write-Host ""
Write-Host "View Tasks:" -ForegroundColor Yellow
Write-Host "  aws --endpoint-url=$Endpoint ecs list-tasks --cluster $ClusterName"
Write-Host ""
Write-Host "NOTE: LocalStack ECS simulates the API but may not actually run containers." -ForegroundColor Magenta
Write-Host "For full ECS testing, you need real AWS or run containers locally." -ForegroundColor Magenta

# Save deployment info
@{
    dockerHubImage = $DockerHubImage
    vpcId = $vpcId
    igwId = $igwId
    subnet1Id = $subnet1Id
    subnet2Id = $subnet2Id
    albArn = $albArn
    albDns = $albDns
    tgArn = $tgArn
    albSgId = $albSgId
    ecsSgId = $ecsSgId
    clusterName = $ClusterName
    serviceName = $ServiceName
} | ConvertTo-Json | Out-File -FilePath ".\infrastructure\deployment-dockerhub.json" -Encoding UTF8
