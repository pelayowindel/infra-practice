# Fix: LocalStack EC2 "Unable to tag Docker image" Error

## Problem

When using LocalStack's EC2 service with Podman, you may encounter the following error:

```
exception while calling ec2.DescribeInstances: Unable to tag Docker image
```

This occurs because LocalStack's EC2 emulation creates containers to simulate EC2 instances, and it needs access to a container runtime socket.

## Root Cause

LocalStack expects a Docker-compatible socket to manage containers for EC2 instance simulation. When using Podman instead of Docker, you need to:
1. Enable Podman's Docker-compatible socket
2. Mount the socket into the LocalStack container

## Solution

### Step 1: Enable Podman Socket

Run this command to enable Podman's socket service inside the Podman VM:

```powershell
podman machine ssh "sudo systemctl enable --now podman.socket"
```

### Step 2: Start LocalStack with Socket Access

Stop any existing LocalStack containers, then start a new one with the socket mounted:

```powershell
# Stop existing LocalStack container (if running)
podman stop <container-name>
podman rm <container-name>

# Start LocalStack with Docker socket access
podman run -d --name localstack-main --privileged `
  -p 4566:4566 `
  -p 4510-4559:4510-4559 `
  -e DOCKER_HOST=unix:///var/run/docker.sock `
  -v /var/run/docker.sock:/var/run/docker.sock `
  docker.io/localstack/localstack:latest
```

For **LocalStack Pro**, add your auth token and use mock VM manager:

```powershell
podman run -d --name localstack-pro --privileged `
  -p 4566:4566 `
  -p 4510-4559:4510-4559 `
  -e LOCALSTACK_AUTH_TOKEN=your-token-here `
  -e DOCKER_HOST=unix:///var/run/docker.sock `
  -e EC2_VM_MANAGER=mock `
  -v /var/run/docker.sock:/var/run/docker.sock `
  docker.io/localstack/localstack-pro:latest
```

> **Note:** The `EC2_VM_MANAGER=mock` option tells LocalStack to simulate EC2 instances without creating actual Docker containers, which resolves the "Unable to tag Docker image" error when using Podman.

### Step 3: Verify EC2 is Working

Wait for LocalStack to start (about 20-30 seconds), then test:

```powershell
# Check health
Invoke-RestMethod -Uri http://localhost:4566/_localstack/health

# Test EC2 DescribeInstances
aws --endpoint-url=http://localhost:4566 ec2 describe-instances --region us-east-1
```

## Key Configuration Options Explained

| Option | Purpose |
|--------|---------|
| `--privileged` | Allows container management inside LocalStack |
| `-v /var/run/docker.sock:/var/run/docker.sock` | Mounts the container runtime socket |
| `-e DOCKER_HOST=unix:///var/run/docker.sock` | Tells LocalStack where to find the socket |

## FAQ

### Do I need to install Docker?

**No.** Podman provides a Docker-compatible socket. The mount path `/var/run/docker.sock` is handled by Podman's VM and mapped to its own socket.

### Why does EC2 need a container socket?

LocalStack simulates EC2 instances by creating actual containers. Each "EC2 instance" is a lightweight container, which requires access to the container runtime.

### The socket command failed, what do I do?

If `podman machine ssh` fails, ensure your Podman machine is running:

```powershell
podman machine list
podman machine start   # if not running
```

## Troubleshooting

### Check LocalStack Logs

```powershell
podman logs localstack-main --tail 100
```

### Verify Podman Socket is Enabled

```powershell
podman machine ssh "systemctl status podman.socket"
```

### Check Container Status

```powershell
podman ps -a
```
