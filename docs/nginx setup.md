# Running .NET API with Nginx Load Balancer

This guide teaches you how to run the .NET Weather API with Nginx as a load balancer. We'll explain everything **before** you run it, so you understand what each command does.

---

## Table of Contents

1. [What You'll Learn](#1-what-youll-learn)
2. [Prerequisites](#2-prerequisites)
3. [Architecture Overview](#3-architecture-overview)
4. [Understanding the Configuration Files](#4-understanding-the-configuration-files)
5. [Understanding the Commands](#5-understanding-the-commands)
6. [Step-by-Step: Running the Application](#6-step-by-step-running-the-application)
7. [Managing Your Application](#7-managing-your-application)
8. [Testing Load Balancing](#8-testing-load-balancing)
9. [Scaling Your Application](#9-scaling-your-application)
10. [Troubleshooting](#10-troubleshooting)
11. [Development Workflow](#11-development-workflow)
12. [Advanced: Load Balancing Algorithms](#12-advanced-load-balancing-algorithms)

---

## 1. What You'll Learn

By the end of this guide, you will understand:

- ✅ What a **Dockerfile** is and how it works
- ✅ What **Docker Compose** does
- ✅ How **Nginx** acts as a load balancer
- ✅ How to **scale** your application to handle more traffic
- ✅ How to **troubleshoot** common issues

---

## 2. Prerequisites

Before starting, make sure you have:

| Requirement | Why You Need It |
|-------------|-----------------|
| **Podman** (or Docker) | To run containers |
| **.NET 9.0 SDK** | To compile your application locally |
| **PowerShell** | To run commands (Windows) |

---

## 3. Architecture Overview

Here's what we're building:

```
User Request
             │
             ▼
┌─────────────────────────────────────────┐
│         Nginx Load Balancer             │
│            (Port 8080)                  │
│      Distributes traffic evenly         │
└───────────────┬─────────────────────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
    ▼           ▼           ▼
┌───────┐   ┌───────┐   ┌───────┐
│ API 1 │   │ API 2 │   │ API 3 │
│ :8080 │   │ :8080 │   │ :8080 │
└───────┘   └───────┘   └───────┘
```

**How it works:**

1. User sends a request to `http://localhost:8080`
2. Nginx receives the request
3. Nginx forwards it to one of the API instances
4. The API responds, and Nginx sends it back to the user

**Why use a load balancer?**

- **High Availability**: If one API instance crashes, others keep working
- **Better Performance**: Distribute work across multiple servers
- **Scalability**: Easily add more instances when traffic increases

---

## 4. Understanding the Configuration Files

Before running any commands, let's understand what each file does.

### 4.1 Dockerfile.simple - The Container Recipe

A **Dockerfile** is like a recipe that tells Podman/Docker how to package your application.

```dockerfile
# Simple Dockerfile - uses pre-published output (no SDK needed)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080
COPY bin/Release/net9.0/publish/ .
ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]
```

#### Line-by-Line Explanation:

| Line | Code | What It Does |
|------|------|--------------|
| 1 | `FROM mcr.microsoft.com/dotnet/aspnet:9.0` | Start with Microsoft's .NET runtime image (like a base template) |
| 2 | `WORKDIR /app` | Create and switch to `/app` folder inside the container |
| 3 | `EXPOSE 8080` | Document that the app uses port 8080 (informational only) |
| 4 | `COPY bin/Release/net9.0/publish/ .` | Copy your compiled app INTO the container |
| 5 | `ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]` | Command to run when container starts |

#### Why `aspnet` instead of `sdk`?

| Image | Size | Contains | Use For |
|-------|------|----------|---------|
| `dotnet/sdk` | ~800 MB | Compiler + runtime | Building code |
| `dotnet/aspnet` | ~220 MB | Runtime only | Running compiled apps |

We compile locally, so we only need the smaller runtime image!

#### Visual: How the Build Works

```
YOUR COMPUTER                              CONTAINER
─────────────────                          ─────────────────

┌─────────────────┐                        ┌─────────────────┐
│ Dockerfile.simple│ ════podman build════► │ Image Created   │
└─────────────────┘                        └─────────────────┘

┌─────────────────┐                               ▲
│ bin/Release/    │                               │
│ net9.0/publish/ │ ──────── COPY ────────────────┘
│   ├─ *.dll      │           
│   └─ *.json     │           
└─────────────────┘
```

---

### 4.2 docker-compose-local.yml - The Orchestrator

**Docker Compose** manages multiple containers as one application.

```yaml
services:
  # Service 1: Nginx Load Balancer
  nginx:
    image: nginx:alpine           # Use official Nginx image
    container_name: nginx-lb      # Name this container "nginx-lb"
    ports:
      - "8080:80"                 # Map your port 8080 → container's port 80
    volumes:
      - ./infrastructure/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - api                       # Start API containers first
    networks:
      - app-network               # Connect to our network

  # Service 2: .NET API (can be scaled)
  api:
    image: localhost/dotnetawsapi:latest    # Your built image
    environment:
      - ASPNETCORE_URLS=http://+:8080       # Listen on port 8080
      - ASPNETCORE_ENVIRONMENT=Production
    expose:
      - "8080"                    # Expose to other containers (not host)
    networks:
      - app-network               # Same network as nginx

networks:
  app-network:
    driver: bridge                # Create an isolated network
```

#### Key Concepts:

| Term | Meaning |
|------|---------|
| `services` | The containers to run |
| `ports: "8080:80"` | YOUR_PORT:CONTAINER_PORT - access container's 80 via your 8080 |
| `expose` | Make port available to OTHER containers only (not your computer) |
| `volumes` | Mount a file from your computer into the container |
| `depends_on` | Start this service AFTER the listed services |
| `networks` | Create an isolated network for containers to communicate |

---

### 4.3 nginx.conf - The Load Balancer Configuration

```nginx
events {
    worker_connections 1024;      # Max simultaneous connections
}

http {
    # Define the group of servers to load balance
    upstream api_servers {
        least_conn;               # Send to server with fewest connections
        server api:8080;          # "api" is resolved by Docker DNS
    }

    server {
        listen 80;                # Nginx listens on port 80

        # Health check endpoint
        location /health {
            return 200 "healthy\n";
        }

        # All other requests go to the API
        location / {
            proxy_pass http://api_servers;          # Forward to our API group
            proxy_set_header Host $host;            # Pass original host header
            proxy_set_header X-Real-IP $remote_addr;# Pass client's real IP
            add_header X-Upstream-Server $upstream_addr;  # Show which server handled it
        }
    }
}
```

#### How Nginx Finds Your API Containers:

When you use `--scale api=3`, Docker creates:

- `api-1` → IP: 10.89.0.2
- `api-2` → IP: 10.89.0.3
- `api-3` → IP: 10.89.0.4

Nginx uses Docker's DNS to find all containers named "api" and distributes traffic.

---

## 5. Understanding the Commands

Before running commands, let's understand what each part means.

### 5.1 The Publish Command

```powershell
dotnet publish -c Release
```

| Part | Meaning |
|------|---------|
| `dotnet` | The .NET CLI tool |
| `publish` | Compile and prepare for deployment |
| `-c Release` | Use Release configuration (optimized, no debug info) |

**Output**: Creates `bin/Release/net9.0/publish/` with your compiled app.

---

### 5.2 The Build Command

```powershell
podman build -t dotnetawsapi:latest -f Dockerfile.simple .
```

| Part | Meaning |
|------|---------|
| `podman build` | Build a container image |
| `-t dotnetawsapi:latest` | **T**ag (name) the image as "dotnetawsapi:latest" |
| `-f Dockerfile.simple` | Use this specific **F**ile |
| `.` | Build context is current directory |

---

### 5.3 The Compose Command

```powershell
podman compose -f docker-compose-local.yml up -d --scale api=3
```

| Part | Meaning |
|------|---------|
| `podman compose` | Run Docker Compose commands |
| `-f docker-compose-local.yml` | Use this compose **F**ile |
| `up` | Create and start containers |
| `-d` | **D**etached mode (run in background) |
| `--scale api=3` | Create 3 instances of the "api" service |

#### Visual: With vs Without `-d`

```
WITHOUT -d (Foreground)          WITH -d (Detached)
─────────────────────────        ─────────────────────────
┌─────────────────────┐          ┌─────────────────────┐
│ > podman compose up │          │ > podman compose -d │
│ Starting nginx...   │          │ Starting nginx...   │
│ Starting api-1...   │          │ Done!               │
│ [logs keep coming]  │          │ >                   │ ← Ready for
│ [Ctrl+C to stop]    │          │ > [type commands]   │   new commands
└─────────────────────┘          └─────────────────────┘
   Terminal blocked               Runs in background
```

---

## 6. Step-by-Step: Running the Application

Now that you understand the files and commands, let's run everything!

### Step 1: Navigate to Project Directory

```powershell
cd "c:\Users\Windel.Pelayo\OneDrive - Dynata, LLC\Documents\Self-teach Prog\Dotnet\dotnetAwsAPI"
```

### Step 2: Publish the Application

```powershell
dotnet publish -c Release
```

**Expected output:**

```
dotnetAwsAPI → bin\Release\net9.0\publish\
Build succeeded in 7.1s
```

### Step 3: Build the Docker Image

```powershell
podman build -t dotnetawsapi:latest -f Dockerfile.simple .
```

**Expected output:**

```
STEP 1/5: FROM mcr.microsoft.com/dotnet/aspnet:9.0
STEP 2/5: WORKDIR /app
STEP 3/5: EXPOSE 8080
STEP 4/5: COPY bin/Release/net9.0/publish/ .
STEP 5/5: ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]
Successfully tagged localhost/dotnetawsapi:latest
```

### Step 4: Start the Load Balancer

```powershell
podman compose -f docker-compose-local.yml up -d --scale api=3
```

**Expected output:**

```
[+] Running 5/5
 ✔ Network dotnetawsapi_app-network  Created
 ✔ Container dotnetawsapi-api-1      Started
 ✔ Container dotnetawsapi-api-2      Started
 ✔ Container dotnetawsapi-api-3      Started
 ✔ Container nginx-lb                Started
```

### Step 5: Verify Everything is Running

```powershell
podman compose -f docker-compose-local.yml ps
```

**Expected output:**

```
NAME                 IMAGE                          STATUS          PORTS
dotnetawsapi-api-1   localhost/dotnetawsapi:latest  Up 30 seconds
dotnetawsapi-api-2   localhost/dotnetawsapi:latest  Up 30 seconds
dotnetawsapi-api-3   localhost/dotnetawsapi:latest  Up 30 seconds
nginx-lb             nginx:alpine                   Up 30 seconds   8080->80/tcp
```

---

## 7. Managing Your Application

### Start/Stop Commands

| Action | Command |
|--------|---------|
| **Start** (3 instances) | `podman compose -f docker-compose-local.yml up -d --scale api=3` |
| **Stop all** | `podman compose -f docker-compose-local.yml down` |
| **Stop** (keep containers) | `podman compose -f docker-compose-local.yml stop` |
| **Restart** | `podman compose -f docker-compose-local.yml restart` |
| **View status** | `podman compose -f docker-compose-local.yml ps` |

### Viewing Logs

```powershell
# All containers
podman compose -f docker-compose-local.yml logs -f

# Nginx only
podman compose -f docker-compose-local.yml logs -f nginx

# API only
podman compose -f docker-compose-local.yml logs -f api
```

---

## 8. Testing Load Balancing

### Available Endpoints

| Endpoint | Description |
|----------|-------------|
| `http://localhost:8080/weatherforecast` | Main API (load balanced) |
| `http://localhost:8080/health` | Nginx health check |
| `http://localhost:8080/lb-status` | Load balancer info |

### Single Request Test

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/weatherforecast"
```

### Load Balancing Test

Run multiple requests and see which server handles each one:

```powershell
for ($i = 1; $i -le 5; $i++) {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/weatherforecast" -UseBasicParsing
    $upstream = $response.Headers["X-Upstream-Server"]
    Write-Host "Request $i - Routed to: $upstream"
}
```

**Expected output:**

```
Request 1 - Routed to: 10.89.0.2:8080
Request 2 - Routed to: 10.89.0.3:8080
Request 3 - Routed to: 10.89.0.4:8080
Request 4 - Routed to: 10.89.0.2:8080
Request 5 - Routed to: 10.89.0.3:8080
```

Different IPs = load balancing is working! ✅

---

## 9. Scaling Your Application

### Scale Up (More Instances)

```powershell
# Increase to 5 instances
podman compose -f docker-compose-local.yml up -d --scale api=5
```

### Scale Down (Fewer Instances)

```powershell
# Reduce to 2 instances
podman compose -f docker-compose-local.yml up -d --scale api=2
```

### Visual: How Scaling Works

```
--scale api=1                    --scale api=3                    --scale api=5
─────────────                    ─────────────                    ─────────────
┌─────────┐                      ┌─────────┐                      ┌─────────┐
│  nginx  │                      │  nginx  │                      │  nginx  │
└────┬────┘                      └────┬────┘                      └────┬────┘
     │                           ┌────┼────┐                  ┌───┬───┼───┬───┐
     ▼                           ▼    ▼    ▼                  ▼   ▼   ▼   ▼   ▼
┌─────────┐                  ┌─────┬─────┬─────┐        ┌───┬───┬───┬───┬───┐
│  api-1  │                  │api-1│api-2│api-3│        │ 1 │ 2 │ 3 │ 4 │ 5 │
└─────────┘                  └─────┴─────┴─────┘        └───┴───┴───┴───┴───┘
```

---

## 10. Troubleshooting

### Problem: Port 8080 Already in Use

```powershell
# Find what's using the port
netstat -ano | findstr :8080
```

**Solution**: Stop the conflicting service, or change the port in `docker-compose-local.yml`:

```yaml
ports:
  - "9090:80"    # Change 8080 to 9090
```

### Problem: Containers Not Starting

```powershell
# Check logs for errors
podman compose -f docker-compose-local.yml logs

# Check if image exists
podman images | Select-String "dotnetawsapi"
```

**Solution**: Rebuild the image:

```powershell
dotnet publish -c Release
podman build -t dotnetawsapi:latest -f Dockerfile.simple .
```

### Problem: Podman VM Issues

```powershell
# Check status
podman machine list

# Restart the VM
podman machine stop
podman machine start
```

---

## 11. Development Workflow

When you make code changes:

```powershell
# 1. Stop current containers
podman compose -f docker-compose-local.yml down

# 2. Rebuild your application
dotnet publish -c Release

# 3. Rebuild the Docker image
podman build -t dotnetawsapi:latest -f Dockerfile.simple .

# 4. Start with load balancer
podman compose -f docker-compose-local.yml up -d --scale api=3

# 5. Test
Invoke-RestMethod -Uri "http://localhost:8080/weatherforecast"
```

---

## 12. Advanced: Load Balancing Algorithms

Edit `infrastructure/nginx/nginx.conf` to change how requests are distributed:

| Algorithm | Configuration | Best For |
|-----------|---------------|----------|
| **Round Robin** | (default) | Equal distribution |
| **Least Connections** | `least_conn;` | Varying request times |
| **IP Hash** | `ip_hash;` | Session persistence |
| **Random** | `random;` | Simple randomization |

### Example: Using Round Robin

```nginx
upstream api_servers {
    # Round robin is default, no directive needed
    server api:8080;
}
```

### Example: Using IP Hash

```nginx
upstream api_servers {
    ip_hash;              # Same user always goes to same server
    server api:8080;
}
```

---

## Summary

Congratulations! You now know how to:

| Skill | Command |
|-------|---------|
| Compile your app | `dotnet publish -c Release` |
| Build a container | `podman build -t name:tag -f Dockerfile .` |
| Start with load balancing | `podman compose -f file.yml up -d --scale api=3` |
| Stop everything | `podman compose -f file.yml down` |
| View logs | `podman compose -f file.yml logs -f` |
| Scale up/down | `podman compose -f file.yml up -d --scale api=N` |

---

## Quick Reference Card

```
┌────────────────────────────────────────────────────────────────┐
│                    QUICK REFERENCE                              │
├────────────────────────────────────────────────────────────────┤
│ START:  podman compose -f docker-compose-local.yml up -d       │
│         --scale api=3                                          │
│                                                                 │
│ STOP:   podman compose -f docker-compose-local.yml down        │
│                                                                 │
│ STATUS: podman compose -f docker-compose-local.yml ps          │
│                                                                 │
│ LOGS:   podman compose -f docker-compose-local.yml logs -f     │
│                                                                 │
│ TEST:   Invoke-RestMethod http://localhost:8080/weatherforecast│
└────────────────────────────────────────────────────────────────┘
```



