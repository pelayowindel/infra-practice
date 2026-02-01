# Understanding Dockerfile: A Complete Beginner's Guide

This guide explains **Dockerfile.simple** line by line. We assume you have **no prior knowledge** about Docker or containers.

---

## Table of Contents

1. [What Problem Are We Solving?](#1-what-problem-are-we-solving)
2. [What is Docker/Podman?](#2-what-is-dockerpodman)
3. [What is a Container?](#3-what-is-a-container)
4. [What is a Docker Image?](#4-what-is-a-docker-image)
5. [What is a Dockerfile?](#5-what-is-a-dockerfile)
6. [Our Dockerfile.simple Explained](#6-our-dockerfilesimple-explained)
7. [The Complete Picture](#7-the-complete-picture)
8. [Common Questions](#8-common-questions)

---

## 1. What Problem Are We Solving?

### The "It Works on My Machine" Problem

Imagine this scenario:

```
Developer: "Here's my app!"
Server Admin: "It doesn't work."
Developer: "But it works on my machine!"
Server Admin: "Your machine has .NET 9.0, ours has .NET 6.0"
Developer: "Oh..."
```

This is a VERY common problem in software development:

| Your Computer | Production Server |
|---------------|-------------------|
| Windows 11 | Linux Ubuntu |
| .NET 9.0 installed | .NET 6.0 installed |
| Specific folder structure | Different folder structure |
| Environment variables set | Different/missing variables |

**Result**: Your application might not work the same way (or at all) on another computer.

### The Solution: Containers

What if we could package:
- Your application code ✅
- The exact .NET version it needs ✅
- The exact operating system settings ✅
- All configuration ✅

...into ONE package that runs **exactly the same** everywhere?

That's what **containers** do!

---

## 2. What is Docker/Podman?

**Docker** (or **Podman**, which we use) is a tool that:

1. **Builds** containers from instructions (Dockerfile)
2. **Runs** containers on any computer
3. **Manages** containers (start, stop, delete)

Think of it like this:

```
┌─────────────────────────────────────────────────────────────┐
│                    ANALOGY: Shipping                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  BEFORE Containers:          AFTER Containers:              │
│                                                             │
│  ┌──────┐ ┌──────┐          ┌─────────────────────┐        │
│  │Apples│ │Chairs│          │ ┌───┐ ┌───┐ ┌───┐  │        │
│  └──────┘ └──────┘          │ │ 📦│ │ 📦│ │ 📦│  │        │
│  ┌──────┐ ┌──────┐          │ └───┘ └───┘ └───┘  │        │
│  │ TVs  │ │Clothes│         │ Standard containers │        │
│  └──────┘ └──────┘          └─────────────────────┘        │
│                                                             │
│  Different shapes,           Same shape, easy to            │
│  hard to transport           stack and transport            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Just like shipping containers standardized global trade, Docker containers standardize software deployment.

### Docker vs Podman

| Feature | Docker | Podman |
|---------|--------|--------|
| Purpose | Run containers | Run containers |
| Commands | `docker build`, `docker run` | `podman build`, `podman run` |
| Requires root/admin? | Yes (daemon) | No (daemonless) |
| Compatible? | - | Yes, same commands |

**We use Podman** because it's more secure and doesn't need a background service running.

---

## 3. What is a Container?

A **container** is like a lightweight, isolated mini-computer running inside your computer.

```
┌─────────────────────────────────────────────────────────────┐
│                     YOUR COMPUTER                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 Operating System                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │ Container 1 │  │ Container 2 │  │ Container 3 │   │  │
│  │  │             │  │             │  │             │   │  │
│  │  │ .NET API    │  │ .NET API    │  │ .NET API    │   │  │
│  │  │ (copy 1)    │  │ (copy 2)    │  │ (copy 3)    │   │  │
│  │  │             │  │             │  │             │   │  │
│  │  │ Has its own:│  │ Has its own:│  │ Has its own:│   │  │
│  │  │ - Files     │  │ - Files     │  │ - Files     │   │  │
│  │  │ - Network   │  │ - Network   │  │ - Network   │   │  │
│  │  │ - Processes │  │ - Processes │  │ - Processes │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Container vs Virtual Machine

You might have heard of Virtual Machines (VMs). Here's the difference:

```
VIRTUAL MACHINE                    CONTAINER
───────────────                    ─────────
┌─────────────┐                    ┌─────────────┐
│   Your App  │                    │   Your App  │
├─────────────┤                    ├─────────────┤
│ Guest OS    │ ← Full OS copy     │ Shared OS   │ ← Uses host OS
│ (Windows)   │   (4-50 GB)        │ kernel      │   (tiny)
├─────────────┤                    └─────────────┘
│ Hypervisor  │
├─────────────┤
│ Host OS     │
└─────────────┘

Startup: Minutes                   Startup: Seconds
Size: Gigabytes                    Size: Megabytes
```

**Containers are faster and lighter!**

---

## 4. What is a Docker Image?

An **image** is like a **template** or **snapshot** that containers are created from.

```
┌─────────────────────────────────────────────────────────────┐
│                    ANALOGY: Cooking                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   RECIPE (Dockerfile)     →     DISH (Image)                │
│   "How to make it"              "The finished product"      │
│                                                             │
│   ┌─────────────────┐           ┌─────────────────┐        │
│   │ 1. Start with   │           │                 │        │
│   │    base image   │    →      │   📦 Image      │        │
│   │ 2. Add files    │  Build    │   "dotnetawsapi"│        │
│   │ 3. Configure    │           │                 │        │
│   └─────────────────┘           └─────────────────┘        │
│                                          │                  │
│                                          │ Run (multiple    │
│                                          ▼ times)           │
│                                 ┌───┐ ┌───┐ ┌───┐          │
│                                 │ 🏃│ │ 🏃│ │ 🏃│          │
│                                 │C1 │ │C2 │ │C3 │          │
│                                 └───┘ └───┘ └───┘          │
│                                 Running containers          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Key points:
- **Dockerfile** = Recipe (instructions)
- **Image** = Prepared dish (built result)
- **Container** = Serving of the dish (running instance)

You can create **many containers** from **one image**.

---

## 5. What is a Dockerfile?

A **Dockerfile** is a text file with instructions for building an image.

It's read **top to bottom**, and each line creates a **layer**.

```
┌─────────────────────────────────────────────────────────────┐
│                    IMAGE LAYERS                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Dockerfile Instructions:        Resulting Image Layers:    │
│                                                             │
│  FROM aspnet:9.0        →       ┌─────────────────────┐    │
│                                 │ Layer 1: Base OS    │    │
│                                 │ (Linux + .NET)      │    │
│                                 ├─────────────────────┤    │
│  WORKDIR /app           →       │ Layer 2: Create     │    │
│                                 │ /app directory      │    │
│                                 ├─────────────────────┤    │
│  COPY files...          →       │ Layer 3: Your app   │    │
│                                 │ files copied in     │    │
│                                 ├─────────────────────┤    │
│  ENTRYPOINT             →       │ Layer 4: Startup    │    │
│                                 │ command defined     │    │
│                                 └─────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Why layers?**
- Layers are **cached** - if nothing changes, it's not rebuilt
- Layers are **shared** - multiple images can share base layers
- This makes builds **fast** and images **smaller**

---

## 6. Our Dockerfile.simple Explained

Now let's look at our actual Dockerfile, line by line.

### The Complete File

```dockerfile
# Simple Dockerfile - uses pre-published output (no SDK needed)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080
COPY bin/Release/net9.0/publish/ .
ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]
```

That's only 6 lines! Let's understand each one.

---

### Line 1: The Comment

```dockerfile
# Simple Dockerfile - uses pre-published output (no SDK needed)
```

| Part | Explanation |
|------|-------------|
| `#` | This is a **comment** - ignored by Docker, just for humans |
| Purpose | Explains that this Dockerfile uses pre-compiled code |

**Why this approach?**
- Normal Dockerfiles compile code INSIDE the container
- That requires the SDK image (~800 MB download)
- We compile OUTSIDE first, so we only need runtime (~220 MB)

---

### Line 2: FROM - The Starting Point

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
```

| Part | Explanation |
|------|-------------|
| `FROM` | Start building from an existing image |
| `mcr.microsoft.com` | Microsoft Container Registry (where the image is stored) |
| `/dotnet/aspnet` | The ASP.NET runtime image |
| `:9.0` | Version tag - we want .NET 9.0 |
| `AS final` | Give this stage a name (useful for multi-stage builds) |

**What does this base image contain?**

```
┌─────────────────────────────────────────┐
│     aspnet:9.0 Base Image Contains:     │
├─────────────────────────────────────────┤
│ ✅ Linux operating system (Debian)      │
│ ✅ .NET 9.0 Runtime                     │
│ ✅ ASP.NET Core libraries               │
│ ✅ HTTPS certificates                   │
│                                         │
│ ❌ Does NOT have: .NET SDK (compiler)   │
│ ❌ Does NOT have: Your application      │
└─────────────────────────────────────────┘
```

**Why aspnet instead of sdk?**

| Image | What It Has | Size | Use For |
|-------|-------------|------|---------|
| `dotnet/sdk:9.0` | Compiler + Runtime + Tools | ~800 MB | Building/compiling code |
| `dotnet/aspnet:9.0` | Runtime only | ~220 MB | Running compiled apps |
| `dotnet/runtime:9.0` | Basic runtime | ~190 MB | Console apps (no web) |

We already compiled our app locally with `dotnet publish`, so we only need the runtime!

---

### Line 3: WORKDIR - Set the Working Directory

```dockerfile
WORKDIR /app
```

| Part | Explanation |
|------|-------------|
| `WORKDIR` | Change to this directory (create it if it doesn't exist) |
| `/app` | The path inside the container |

**What this does:**

```
BEFORE WORKDIR              AFTER WORKDIR
──────────────              ─────────────
You are here: /             You are here: /app

/                           /
├── bin/                    ├── bin/
├── etc/                    ├── etc/
├── home/                   ├── home/
└── ...                     └── app/        ← You are now here
                                             (created if missing)
```

**Why do we need this?**
- Keeps things organized - your app goes in `/app`
- All following commands run FROM this directory
- It's a convention - most Docker images use `/app`

---

### Line 4: EXPOSE - Document the Port

```dockerfile
EXPOSE 8080
```

| Part | Explanation |
|------|-------------|
| `EXPOSE` | Document which port the application listens on |
| `8080` | The **container's** port (NOT your computer's port) |

**Understanding Host vs Container Ports:**

```
YOUR COMPUTER (Host)              CONTAINER
─────────────────────             ─────────────

                                  ┌─────────────────┐
                                  │ EXPOSE 8080     │
     Port 8080  ◄───────────────► │ (Container's    │
     (Host)         -p 8080:8080  │  internal port) │
                                  │                 │
                                  │ .NET App runs   │
                                  │ on port 8080    │
                                  └─────────────────┘
```

**The `-p` flag connects them:**

```powershell
podman run -p 8080:8080 myimage
#           ↑     ↑
#           │     └── Container port (what EXPOSE documents)
#           └── Host port (your computer - how YOU access it)
```

**You can use DIFFERENT ports:**

```powershell
podman run -p 3000:8080 myimage
#           ↑     ↑
#           │     └── Container still uses 8080 internally
#           └── But YOU access it via localhost:3000
```

**Important misconception:**

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️  EXPOSE does NOT actually open/publish the port!        │
│                                                             │
│  It's just documentation saying:                            │
│  "This app uses port 8080 INSIDE the container"            │
│                                                             │
│  To ACTUALLY make the port accessible from your computer:   │
│  podman run -p HOST_PORT:CONTAINER_PORT ...                │
│             ↑                                               │
│             This is what actually maps the ports            │
└─────────────────────────────────────────────────────────────┘
```

**Why include EXPOSE then?**
- Documentation for other developers
- Some tools use it for auto-configuration
- Best practice to be explicit about what port your app uses

---

### Line 5: COPY - Add Your Application

```dockerfile
COPY bin/Release/net9.0/publish/ .
```

| Part | Explanation |
|------|-------------|
| `COPY` | Copy files from your computer INTO the container |
| `bin/Release/net9.0/publish/` | Source: Your compiled app folder |
| `.` | Destination: Current directory (`/app` from WORKDIR) |

**Visual explanation:**

```
YOUR COMPUTER                           CONTAINER
─────────────                           ─────────

dotnetAwsAPI/                           /app/
├── bin/                                ├── dotnetAwsAPI.dll     ✅
│   └── Release/                        ├── dotnetAwsAPI.deps.json
│       └── net9.0/                     ├── dotnetAwsAPI.runtimeconfig.json
│           └── publish/     ──COPY──►  ├── appsettings.json
│               ├── dotnetAwsAPI.dll    └── (other files...)
│               ├── appsettings.json
│               └── ...
├── Program.cs          ❌ NOT copied
├── Dockerfile.simple   ❌ NOT copied
└── ...
```

**Why copy from `publish/` folder?**

The `dotnet publish` command creates a **deployment-ready** folder:
- Contains only files needed to run (not source code)
- Optimized for the target framework
- Includes all dependencies

---

### Line 6: ENTRYPOINT - The Startup Command

```dockerfile
ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]
```

| Part | Explanation |
|------|-------------|
| `ENTRYPOINT` | The command that runs when the container starts |
| `["dotnet", "dotnetAwsAPI.dll"]` | Run our application using the dotnet command |

**This is equivalent to running:**

```bash
dotnet dotnetAwsAPI.dll
```

**Why the array format `["dotnet", "dotnetAwsAPI.dll"]`?**

There are two formats:

```dockerfile
# Shell form (NOT recommended)
ENTRYPOINT dotnet dotnetAwsAPI.dll

# Exec form (RECOMMENDED)
ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]
```

| Format | How it runs | Signals handled? | Recommended? |
|--------|-------------|------------------|--------------|
| Shell form | Via `/bin/sh -c` | ❌ No | No |
| Exec form | Directly | ✅ Yes | Yes |

The exec form (with brackets) allows your app to:
- Receive shutdown signals properly
- Start faster (no shell overhead)
- Be more secure

---

## 7. The Complete Picture

Let's see the entire workflow from source code to running container:

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE WORKFLOW                             │
└─────────────────────────────────────────────────────────────────┘

STEP 1: Write Code
───────────────────
┌─────────────────┐
│ Program.cs      │  Your .NET source code
│ *.csproj        │
└────────┬────────┘
         │
         ▼
STEP 2: Publish (on your computer)
──────────────────────────────────
Command: dotnet publish -c Release

┌─────────────────┐
│ bin/Release/    │
│ net9.0/publish/ │  Compiled, ready-to-run files
│   ├── *.dll     │
│   └── *.json    │
└────────┬────────┘
         │
         ▼
STEP 3: Build Image (Podman reads Dockerfile)
─────────────────────────────────────────────
Command: podman build -t dotnetawsapi:latest -f Dockerfile.simple .

┌─────────────────┐     ┌──────────────────┐
│ Dockerfile      │ ──► │ Docker Image     │
│ .simple         │     │ "dotnetawsapi"   │
└─────────────────┘     │                  │
                        │ Contains:        │
┌─────────────────┐     │ - Linux OS       │
│ bin/Release/    │ ──► │ - .NET Runtime   │
│ net9.0/publish/ │     │ - Your app files │
└─────────────────┘     └────────┬─────────┘
                                 │
                                 ▼
STEP 4: Run Container(s)
────────────────────────
Command: podman run -p 8080:8080 dotnetawsapi:latest

                        ┌─────────────────┐
                        │ Container       │
                   ┌───►│ (Running app)   │
                   │    └─────────────────┘
┌──────────────┐   │    ┌─────────────────┐
│ Docker Image │───┼───►│ Container       │
│ "dotnetawsapi"│  │    │ (Running app)   │
└──────────────┘   │    └─────────────────┘
                   │    ┌─────────────────┐
                   └───►│ Container       │
                        │ (Running app)   │
                        └─────────────────┘

One image → Many containers!
```

---

## 8. Common Questions

### Q: Why do we publish locally instead of in the Dockerfile?

**Short answer**: To avoid downloading the 800MB SDK image.

**Long answer**:

```
APPROACH 1: Multi-stage Dockerfile (Traditional)
────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build    ← Downloads ~800 MB
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release

FROM mcr.microsoft.com/dotnet/aspnet:9.0          ← Downloads ~220 MB
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "app.dll"]

Total download: ~1 GB


APPROACH 2: Our Simple Dockerfile
─────────────────────────────────
dotnet publish -c Release                          ← Uses SDK already on your PC
FROM mcr.microsoft.com/dotnet/aspnet:9.0          ← Downloads ~220 MB only
COPY bin/Release/net9.0/publish/ .
ENTRYPOINT ["dotnet", "dotnetAwsAPI.dll"]

Total download: ~220 MB (if aspnet image not cached)
```

We chose the simple approach because:
1. Faster builds (no SDK download)
2. Works better with Podman on Windows
3. Simpler to understand

---

### Q: What does each file in the publish folder do?

| File | Purpose |
|------|---------|
| `dotnetAwsAPI.dll` | Your compiled application code |
| `dotnetAwsAPI.deps.json` | Lists all dependencies |
| `dotnetAwsAPI.runtimeconfig.json` | Tells .NET how to run your app |
| `appsettings.json` | Your app configuration |
| `*.dll` (others) | NuGet package dependencies |

---

### Q: Can I use a different base image?

Yes! Here are options:

| Base Image | Size | OS | Notes |
|------------|------|-----|-------|
| `aspnet:9.0` | ~220 MB | Debian | Default, most compatible |
| `aspnet:9.0-alpine` | ~110 MB | Alpine Linux | Smaller, but may have compatibility issues |
| `aspnet:9.0-noble` | ~230 MB | Ubuntu 24.04 | If you need Ubuntu |

To use Alpine (smaller):
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS final
```

---

### Q: How do I update my application?

When you change your code:

```powershell
# 1. Recompile your app
dotnet publish -c Release

# 2. Rebuild the Docker image
podman build -t dotnetawsapi:latest -f Dockerfile.simple .

# 3. Restart containers (if using compose)
podman compose -f docker-compose-local.yml down
podman compose -f docker-compose-local.yml up -d --scale api=3
```

---

## Summary

Here's what our Dockerfile.simple does in plain English:

```
┌────────────────────────────────────────────────────────────────┐
│ "Start with Microsoft's .NET 9.0 runtime image,                │
│  create a folder called /app,                                  │
│  note that we'll use port 8080,                                │
│  copy our pre-compiled application into the container,         │
│  and when the container starts, run our application."          │
└────────────────────────────────────────────────────────────────┘
```

That's it! 🎉

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│                 DOCKERFILE COMMANDS                          │
├──────────────┬──────────────────────────────────────────────┤
│ FROM         │ Start from a base image                      │
│ WORKDIR      │ Set the working directory                    │
│ EXPOSE       │ Document which port is used                  │
│ COPY         │ Copy files into the container                │
│ ENTRYPOINT   │ Command to run when container starts         │
├──────────────┴──────────────────────────────────────────────┤
│ OTHER USEFUL COMMANDS (not in our simple Dockerfile):       │
├──────────────┬──────────────────────────────────────────────┤
│ RUN          │ Execute a command during build               │
│ ENV          │ Set environment variables                    │
│ ARG          │ Define build-time variables                  │
│ CMD          │ Default command (can be overridden)          │
│ ADD          │ Like COPY, but can extract archives          │
└──────────────┴──────────────────────────────────────────────┘
```
