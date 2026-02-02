# Understanding Nginx: A Complete Beginner's Guide

This guide explains **nginx.conf** line by line. We assume you have **no prior knowledge** about Nginx or web servers.

---

## Table of Contents

1. [What Problem Are We Solving?](#1-what-problem-are-we-solving)
2. [What is Nginx?](#2-what-is-nginx)
3. [What is a Reverse Proxy?](#3-what-is-a-reverse-proxy)
4. [What is Load Balancing?](#4-what-is-load-balancing)
5. [Nginx Configuration Structure](#5-nginx-configuration-structure)
6. [Our nginx.conf Explained](#6-our-nginxconf-explained)
7. [Load Balancing Algorithms](#7-load-balancing-algorithms)
8. [Common Questions](#8-common-questions)

---

## 1. What Problem Are We Solving?

### Problem 1: One Server Can't Handle Everything

Imagine you have a popular website:

```
         1000 users
              │
              ▼
       ┌─────────────┐
       │  Single     │
       │  API Server │  ← Overloaded! 😰
       │             │     - Slow responses
       └─────────────┘     - May crash
```

**Solution**: Use MULTIPLE servers and split the traffic!

```
         1000 users
              │
              ▼
       ┌─────────────┐
       │   Nginx     │  ← Traffic cop 👮
       │ Load Balancer│
       └──────┬──────┘
              │
    ┌─────────┼─────────┐
    │         │         │
    ▼         ▼         ▼
┌───────┐ ┌───────┐ ┌───────┐
│ API 1 │ │ API 2 │ │ API 3 │
│ ~333  │ │ ~333  │ │ ~333  │  ← Each handles 1/3
│ users │ │ users │ │ users │     of the traffic 😊
└───────┘ └───────┘ └───────┘
```

### Problem 2: Hiding Internal Details

You don't want users to know your internal server addresses:
- ❌ Bad: Users access `http://192.168.1.50:8080`
- ✅ Good: Users access `http://myapp.com`

Nginx hides your internal servers and provides ONE entry point.

### Problem 3: High Availability

What if one server crashes?

```
WITHOUT Load Balancer:          WITH Load Balancer:
──────────────────────          ──────────────────────

     User                            User
       │                               │
       ▼                               ▼
  ┌─────────┐                    ┌─────────┐
  │   API   │ ← Crashed!         │  Nginx  │
  │  💀💀💀  │                    └────┬────┘
  └─────────┘                         │
                                ┌─────┼─────┐
     ❌ Website down!           ▼     ▼     ▼
                             ┌───┐ ┌───┐ ┌───┐
                             │ 1 │ │💀 │ │ 3 │
                             │ ✅│ │   │ │ ✅│
                             └───┘ └───┘ └───┘

                             ✅ Still working!
                               (Nginx skips the dead server)
```

---

## 2. What is Nginx?

**Nginx** (pronounced "engine-x") is a high-performance web server that can act as:

| Role | What It Does |
|------|--------------|
| **Web Server** | Serve static files (HTML, CSS, images) |
| **Reverse Proxy** | Forward requests to other servers |
| **Load Balancer** | Distribute traffic across multiple servers |
| **Cache** | Store responses to speed up repeated requests |
| **SSL Terminator** | Handle HTTPS encryption |

In our setup, we use Nginx as a **Reverse Proxy** and **Load Balancer**.

### Why Nginx is Popular

```
┌─────────────────────────────────────────────────────────────┐
│                 NGINX STATISTICS                             │
├─────────────────────────────────────────────────────────────┤
│  • Powers ~30% of all websites on the internet              │
│  • Used by: Netflix, Airbnb, Pinterest, WordPress           │
│  • Can handle 10,000+ simultaneous connections              │
│  • Written in C - extremely fast and lightweight            │
│  • Open source and free                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. What is a Reverse Proxy?

### Regular Proxy vs Reverse Proxy

**Regular Proxy** (Forward Proxy):
- Sits between USER and the internet
- Protects/hides the USER
- Example: VPN, corporate proxy

```
User → [Proxy] → Internet
       ↑
       Hides user from websites
```

**Reverse Proxy**:
- Sits between internet and SERVERS
- Protects/hides the SERVERS
- Example: Nginx, AWS ALB

```
Internet → [Reverse Proxy] → Servers
           ↑
           Hides servers from users
```

### Visual Comparison

```
FORWARD PROXY                    REVERSE PROXY
─────────────                    ─────────────

User wants to hide               Server wants to hide
from websites                    from users

┌──────┐                         ┌──────────┐
│ User │──┐                      │ Internet │──┐
└──────┘  │                      └──────────┘  │
          │    ┌───────────┐                   │    ┌───────────┐
          ├───►│   Proxy   │                   └───►│  Reverse  │
          │    └─────┬─────┘                        │   Proxy   │
┌──────┐  │          │                              │  (Nginx)  │
│ User │──┘          ▼                              └─────┬─────┘
└──────┘       ┌──────────┐                               │
               │ Internet │                    ┌──────────┼──────────┐
               └──────────┘                    ▼          ▼          ▼
                                            ┌─────┐   ┌─────┐   ┌─────┐
"Hide ME from                               │API 1│   │API 2│   │API 3│
 the website"                               └─────┘   └─────┘   └─────┘

                                         "Hide our SERVERS
                                          from users"
```

---

## 4. What is Load Balancing?

**Load balancing** = distributing incoming traffic across multiple servers.

### Analogy: Supermarket Checkout

```
┌─────────────────────────────────────────────────────────────┐
│                    SUPERMARKET ANALOGY                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  WITHOUT Load Balancing:       WITH Load Balancing:         │
│                                                             │
│  All customers → 1 register    Manager directs customers    │
│                                                             │
│  😰😰😰😰😰😰→ [Register 1]     😊→ [Register 1]            │
│                 Long queue!     😊→ [Register 2]            │
│                                 😊→ [Register 3]            │
│                                                             │
│                                 👮 Manager = Nginx          │
│                                    (Load Balancer)          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Benefits of Load Balancing

| Benefit | Explanation |
|---------|-------------|
| **Scalability** | Handle more users by adding more servers |
| **Reliability** | If one server dies, others keep working |
| **Speed** | Each server has less work = faster responses |
| **Maintenance** | Update servers one at a time without downtime |

---

## 5. Nginx Configuration Structure

Before diving into our config, let's understand how Nginx configs are organized.

### The Hierarchy

```
nginx.conf
    │
    ├── events { }           ← Connection handling settings
    │
    └── http { }             ← HTTP server settings
            │
            ├── upstream { }  ← Define server groups
            │
            └── server { }    ← Virtual server settings
                    │
                    └── location { }  ← URL path rules
```

### Block Structure

Nginx uses **blocks** (sections) wrapped in curly braces `{ }`:

```nginx
block_name {
    directive value;
    directive value;
    
    nested_block {
        directive value;
    }
}
```

### Terminology

| Term | Meaning | Example |
|------|---------|---------|
| **Block** | A section with `{ }` | `http { }`, `server { }` |
| **Directive** | A setting | `listen 80;` |
| **Context** | Where a directive can be used | `http`, `server`, `location` |

---

## 6. Our nginx.conf Explained

Now let's go through our configuration file, line by line.

### The Complete File

```nginx
events {
    worker_connections 1024;
}

http {
    upstream api_servers {
        least_conn;
        server api:8080;
    }

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" upstream: $upstream_addr';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    server {
        listen 80;
        server_name localhost;

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        location /lb-status {
            add_header Content-Type text/plain;
            return 200 "Load Balancer: nginx\nUpstream: api_servers\n";
        }

        location / {
            proxy_pass http://api_servers;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            add_header X-Upstream-Server $upstream_addr;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }
    }
}
```

---

### Section 1: Events Block

```nginx
events {
    worker_connections 1024;
}
```

| Directive | Value | Meaning |
|-----------|-------|---------|
| `events` | - | Block for connection settings |
| `worker_connections` | `1024` | Max connections PER worker process |

**What is a worker?**

```
┌─────────────────────────────────────────────────────────────┐
│                    NGINX ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐                                        │
│  │  Master Process │  ← Reads config, manages workers       │
│  └────────┬────────┘                                        │
│           │                                                 │
│     ┌─────┴─────┐                                          │
│     ▼           ▼                                          │
│  ┌────────┐ ┌────────┐                                     │
│  │Worker 1│ │Worker 2│  ← Actually handle connections      │
│  │        │ │        │                                     │
│  │ 1024   │ │ 1024   │  ← Each can handle 1024 connections │
│  │ conns  │ │ conns  │                                     │
│  └────────┘ └────────┘                                     │
│                                                             │
│  Total capacity: 2 workers × 1024 = 2048 connections       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Why 1024?**
- Default is often 512
- 1024 is good for medium traffic
- Production servers might use 4096 or higher

---

### Section 2: HTTP Block

```nginx
http {
    # Everything HTTP-related goes here
}
```

This block contains all HTTP/web server configuration.

---

### Section 3: Upstream Block (The Load Balancer)

```nginx
upstream api_servers {
    least_conn;
    server api:8080;
}
```

| Line | Meaning |
|------|---------|
| `upstream api_servers` | Create a group of servers called "api_servers" |
| `least_conn;` | Load balancing algorithm (explained below) |
| `server api:8080;` | Add server "api" on port 8080 to the group |

**How does `server api:8080` work?**

```
┌─────────────────────────────────────────────────────────────┐
│                    DOCKER DNS MAGIC                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  In docker-compose.yml, we scaled: --scale api=3           │
│                                                             │
│  Docker creates:                                            │
│                                                             │
│  Container Name        Internal IP                          │
│  ───────────────       ───────────                          │
│  dotnetawsapi-api-1    10.89.0.2                            │
│  dotnetawsapi-api-2    10.89.0.3                            │
│  dotnetawsapi-api-3    10.89.0.4                            │
│                                                             │
│  When Nginx asks Docker DNS: "Where is 'api'?"             │
│  Docker replies: "10.89.0.2, 10.89.0.3, 10.89.0.4"         │
│                                                             │
│  Nginx now knows ALL the servers! 🎉                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**This is why we don't list individual IPs** - Docker handles it automatically!

---

### Section 4: Logging Configuration

```nginx
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" upstream: $upstream_addr';

access_log /var/log/nginx/access.log main;
error_log /var/log/nginx/error.log warn;
```

| Directive | Meaning |
|-----------|---------|
| `log_format main` | Define a log format named "main" |
| `access_log` | Where to save access logs + which format |
| `error_log` | Where to save error logs + minimum level |

**Log Variables Explained:**

| Variable | What It Contains | Example |
|----------|------------------|---------|
| `$remote_addr` | Client's IP address | `192.168.1.100` |
| `$remote_user` | Authenticated username | `john` or `-` |
| `$time_local` | Request timestamp | `01/Feb/2026:10:30:45 +0000` |
| `$request` | Full request line | `GET /weatherforecast HTTP/1.1` |
| `$status` | Response status code | `200`, `404`, `500` |
| `$body_bytes_sent` | Response size | `1234` |
| `$http_referer` | Where user came from | `https://google.com` |
| `$http_user_agent` | Browser/client info | `Mozilla/5.0...` |
| `$upstream_addr` | Which backend server | `10.89.0.2:8080` |

**Example Log Line:**

```
192.168.1.100 - - [01/Feb/2026:10:30:45 +0000] "GET /weatherforecast HTTP/1.1" 200 1234 "-" "curl/7.68.0" upstream: 10.89.0.2:8080
```

---

### Section 5: Server Block

```nginx
server {
    listen 80;
    server_name localhost;
    
    # location blocks...
}
```

| Directive | Value | Meaning |
|-----------|-------|---------|
| `server` | - | Define a virtual server |
| `listen` | `80` | Listen on port 80 (HTTP) |
| `server_name` | `localhost` | Respond to requests for "localhost" |

**Multiple Server Blocks:**

You can have multiple servers for different domains:

```nginx
server {
    listen 80;
    server_name api.myapp.com;
    # Config for API
}

server {
    listen 80;
    server_name www.myapp.com;
    # Config for website
}
```

---

### Section 6: Location Blocks

Location blocks define rules for different URL paths.

#### Location: Health Check

```nginx
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```

| Directive | Meaning |
|-----------|---------|
| `location /health` | Match requests starting with `/health` |
| `access_log off` | Don't log these requests (reduces log noise) |
| `return 200 "healthy\n"` | Return status 200 with body "healthy" |
| `add_header Content-Type text/plain` | Set response content type |

**Why have a health check?**
- Kubernetes/Docker can ping this to verify Nginx is alive
- Load balancers use it to check availability
- Monitoring tools use it for uptime checks

---

#### Location: Load Balancer Status

```nginx
location /lb-status {
    add_header Content-Type text/plain;
    return 200 "Load Balancer: nginx\nUpstream: api_servers\n";
}
```

A simple endpoint to confirm the load balancer is working.

---

#### Location: Everything Else (The Main Route)

```nginx
location / {
    proxy_pass http://api_servers;
    
    # ... more directives
}
```

`location /` matches ALL requests that don't match more specific locations.

---

### Section 7: Proxy Directives (Forwarding to API)

```nginx
proxy_pass http://api_servers;
```

| Directive | Meaning |
|-----------|---------|
| `proxy_pass` | Forward requests to this address |
| `http://api_servers` | Our upstream group defined earlier |

**Visual Flow:**

```
User Request                         Nginx                          API Server
────────────                         ─────                          ──────────

GET /weatherforecast  ───────►  proxy_pass  ───────►  GET /weatherforecast
                                http://api_servers
                                     │
                                     ▼
                               Pick one server
                               (least connections)
```

---

### Section 8: Proxy Headers

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

**Why do we need these?**

When Nginx forwards requests, the API sees Nginx as the client, not the real user!

```
WITHOUT Headers:                     WITH Headers:
────────────────                     ─────────────

User (1.2.3.4)                       User (1.2.3.4)
     │                                    │
     ▼                                    ▼
   Nginx (10.89.0.1)                    Nginx (10.89.0.1)
     │                                    │
     ▼                                    ▼
   API sees:                            API sees:
   Client IP: 10.89.0.1 ❌              Client IP: 10.89.0.1
   (Nginx's IP, not user's!)            X-Real-IP: 1.2.3.4 ✅
                                        (Real user's IP!)
```

**Header Explanations:**

| Header | What It Contains | Why Needed |
|--------|------------------|------------|
| `Host` | Original hostname | API knows which domain was requested |
| `X-Real-IP` | User's real IP | API can log/rate-limit actual users |
| `X-Forwarded-For` | Chain of proxy IPs | Track request path through proxies |
| `X-Forwarded-Proto` | `http` or `https` | API knows if original was secure |

---

### Section 9: Response Header

```nginx
add_header X-Upstream-Server $upstream_addr;
```

This adds a header to the RESPONSE showing which backend handled it.

**Testing:**

```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8080/weatherforecast" -UseBasicParsing
$response.Headers["X-Upstream-Server"]
# Output: 10.89.0.2:8080
```

This helps you verify load balancing is working!

---

### Section 10: Timeout Settings

```nginx
proxy_connect_timeout 30s;
proxy_send_timeout 30s;
proxy_read_timeout 30s;
```

| Directive | Default | Our Value | Meaning |
|-----------|---------|-----------|---------|
| `proxy_connect_timeout` | 60s | 30s | Time to establish connection to backend |
| `proxy_send_timeout` | 60s | 30s | Time to send request to backend |
| `proxy_read_timeout` | 60s | 30s | Time to wait for response from backend |

**What happens on timeout?**

```
┌─────────────────────────────────────────────────────────────┐
│                    TIMEOUT SCENARIO                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. User sends request                                      │
│  2. Nginx forwards to API                                   │
│  3. API is slow/stuck                                       │
│  4. 30 seconds pass...                                      │
│  5. Nginx gives up, returns 504 Gateway Timeout             │
│                                                             │
│  This prevents requests from hanging forever!               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### Section 11: Buffering Settings

```nginx
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
```

| Directive | Value | Meaning |
|-----------|-------|---------|
| `proxy_buffering` | `on` | Enable buffering of backend responses |
| `proxy_buffer_size` | `4k` | Buffer for response headers |
| `proxy_buffers` | `8 4k` | 8 buffers of 4KB each for response body |

**What is buffering?**

```
WITHOUT Buffering:              WITH Buffering:
──────────────────              ───────────────

API sends slowly:               API sends slowly:
  ▼                               ▼
  chunk1 → Nginx → User           chunk1 ─┐
  chunk2 → Nginx → User           chunk2 ─┼─► Nginx [buffer] → User (all at once)
  chunk3 → Nginx → User           chunk3 ─┘

User sees: slow, choppy         User sees: smooth delivery
```

**Benefits:**
- API connection freed quickly
- Smoother response delivery to slow clients
- Better memory management

---

## 7. Load Balancing Algorithms

The `upstream` block can use different algorithms:

### Round Robin (Default)

```nginx
upstream api_servers {
    # No directive needed - it's the default
    server api:8080;
}
```

```
Request 1 → Server 1
Request 2 → Server 2
Request 3 → Server 3
Request 4 → Server 1  ← Cycles back
Request 5 → Server 2
...
```

**Best for**: Servers with equal capacity, similar request complexity.

---

### Least Connections (Our Choice)

```nginx
upstream api_servers {
    least_conn;
    server api:8080;
}
```

```
Server 1: 5 active connections
Server 2: 2 active connections  ← Next request goes here!
Server 3: 7 active connections
```

**Best for**: Requests with varying processing times.

---

### IP Hash (Session Persistence)

```nginx
upstream api_servers {
    ip_hash;
    server api:8080;
}
```

```
User 1.2.3.4 → Always goes to Server 2
User 5.6.7.8 → Always goes to Server 1
User 9.0.1.2 → Always goes to Server 3
```

**Best for**: Applications needing session persistence (shopping carts, logins).

---

### Comparison Table

| Algorithm | Directive | How It Works | Use When |
|-----------|-----------|--------------|----------|
| Round Robin | (default) | Rotates through servers | Servers are equal |
| Least Conn | `least_conn;` | Picks least busy server | Requests vary in time |
| IP Hash | `ip_hash;` | Same user → same server | Need sessions |
| Random | `random;` | Random selection | Simple distribution |
| Weighted | `server ... weight=3;` | Prioritize some servers | Servers have different capacities |

---

## 8. Common Questions

### Q: How does Nginx know when a server is down?

Nginx detects failed servers automatically:

```nginx
upstream api_servers {
    server api:8080 max_fails=3 fail_timeout=30s;
}
```

| Setting | Meaning |
|---------|---------|
| `max_fails=3` | After 3 failed requests... |
| `fail_timeout=30s` | ...mark server as down for 30 seconds |

After 30 seconds, Nginx tries again.

---

### Q: Can I have servers with different capacities?

Yes! Use weights:

```nginx
upstream api_servers {
    server api1:8080 weight=3;  # Gets 3x traffic
    server api2:8080 weight=1;  # Gets 1x traffic
    server api3:8080 weight=1;  # Gets 1x traffic
}
```

Traffic distribution: 60% / 20% / 20%

---

### Q: How do I add HTTPS?

```nginx
server {
    listen 443 ssl;
    server_name myapp.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://api_servers;
    }
}
```

---

### Q: How do I reload config without downtime?

```bash
nginx -s reload
```

Or in our container:
```powershell
podman exec nginx-lb nginx -s reload
```

---

## Summary

Here's what our nginx.conf does in plain English:

```
┌────────────────────────────────────────────────────────────────┐
│ "Accept up to 1024 connections per worker.                     │
│                                                                │
│  Create a group of API servers called 'api_servers'.          │
│  Use 'least connections' to pick which server gets requests.  │
│                                                                │
│  Listen on port 80.                                           │
│                                                                │
│  For /health requests: respond 'healthy' (for monitoring).    │
│  For /lb-status: respond with load balancer info.             │
│  For all other requests: forward to the API servers,          │
│    passing along the real user's IP and other info.           │
│                                                                │
│  Wait max 30 seconds for responses.                           │
│  Buffer responses for smooth delivery."                        │
└────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│                 NGINX.CONF STRUCTURE                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  events { }       ← Connection settings                     │
│                                                             │
│  http {           ← HTTP server settings                    │
│                                                             │
│      upstream { }  ← Define server groups for load balancing│
│                                                             │
│      server {      ← Virtual server definition              │
│                                                             │
│          location / { }  ← Rules for URL paths              │
│      }                                                      │
│  }                                                          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 KEY DIRECTIVES                               │
├──────────────────────┬──────────────────────────────────────┤
│ listen               │ Port to listen on                    │
│ server_name          │ Domain/hostname to respond to        │
│ location             │ Match URL paths                      │
│ proxy_pass           │ Forward to backend servers           │
│ proxy_set_header     │ Pass headers to backend              │
│ upstream             │ Define load balancing group          │
│ least_conn           │ Use least connections algorithm      │
└──────────────────────┴──────────────────────────────────────┘
```
