# Complete Kubernetes Ingress Course - Units 1-6

## Course Overview

This comprehensive course takes you from Kubernetes Ingress fundamentals to building production-grade applications. Through hands-on projects, you'll master routing, security, performance optimization, and real-world deployment patterns.

**Learning Path**: Foundations → Environment Setup → Simple Applications → Complex Routing → Security → Production E-commerce Platform

---

# Unit 1: Understanding Ingress Fundamentals

*Note: This unit's detailed content needs to be developed based on the course progression*

## Learning Objectives
- Understand what Kubernetes Ingress is and why it's needed
- Learn the difference between Services and Ingress
- Explore Ingress Controllers and their role
- Understand routing concepts and traffic flow

## Key Concepts to Cover
- **What is Ingress?** - L7 routing vs L4 load balancing
- **Ingress vs Services** - When to use each
- **Ingress Controllers** - nginx, Traefik, HAProxy options
- **Basic Routing Patterns** - Host-based, path-based routing
- **Traffic Flow** - Client → Ingress Controller → Service → Pod

## Self-Assessment Questions
1. What problems does Ingress solve that Services cannot?
2. How does an Ingress Controller differ from an Ingress resource?
3. What are the main routing strategies available with Ingress?

---

# Unit 2: Setting Up Your Learning Environment

## Project Overview
Before diving into Ingress configurations, you need a reliable Kubernetes environment. This unit walks you through setting up a complete local development environment that mirrors production patterns.

## Learning Objectives
By the end of this unit, you'll be able to:
- Set up a local Kubernetes cluster with minikube
- Install and configure the NGINX Ingress Controller
- Understand the components of an Ingress-enabled cluster
- Troubleshoot common setup issues

## Prerequisites
- Basic familiarity with Docker concepts
- Command-line comfort (bash/terminal)
- Understanding of YAML syntax
- Basic networking concepts (DNS, HTTP)

## Phase 1: Environment Setup

### Install Required Tools

```bash
# Install minikube (macOS example - adjust for your OS)
brew install minikube

# Install kubectl
brew install kubectl

# Verify installations
minikube version
kubectl version --client
```

### Start Your Kubernetes Cluster

```bash
# Start minikube with sufficient resources
minikube start --driver=docker --cpus=4 --memory=4096

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

### Install NGINX Ingress Controller

```bash
# Enable the ingress addon
minikube addons enable ingress

# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress class
kubectl get ingressclass
```

## Phase 2: Verify Your Environment

### Test Basic Functionality

```bash
# Create a simple test deployment
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0

# Expose it as a service
kubectl expose deployment hello-world --port=8080 --target-port=8080

# Create a basic ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: hello-world.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 8080
EOF

# Get minikube IP and set up local DNS
echo "$(minikube ip) hello-world.local" | sudo tee -a /etc/hosts

# Test the setup
curl http://hello-world.local
```

### Understanding Your Environment

Your local setup now includes:
- **Minikube**: Local Kubernetes cluster
- **NGINX Ingress Controller**: Routes external traffic
- **kubectl**: Command-line interface
- **Local DNS**: Maps hostnames to your cluster

## Phase 3: Environment Verification Checklist

Run through this checklist to ensure everything works:

- [ ] Minikube cluster starts without errors
- [ ] kubectl can communicate with cluster
- [ ] Ingress controller pods are running
- [ ] Test application responds via Ingress
- [ ] Local DNS resolution works

## Troubleshooting Common Issues

### Issue: Minikube won't start
**Solution**: Check Docker is running, ensure sufficient system resources

### Issue: Ingress controller pods stuck in pending
**Solution**: Restart minikube with more resources: `minikube start --cpus=4 --memory=4096`

### Issue: curl returns connection refused
**Check**: Verify minikube IP with `minikube ip` and update /etc/hosts

## Clean-up

```bash
# Clean up test resources
kubectl delete ingress hello-world-ingress
kubectl delete service hello-world
kubectl delete deployment hello-world

# Remove from hosts file
sudo sed -i '/hello-world.local/d' /etc/hosts
```

## Preparing for Unit 3

In the next unit, you'll build your first real web application with Ingress. Consider:
1. What types of routing might a web application need?
2. How would you handle multiple environments (dev, staging, prod)?

---

# Unit 3: Mini-Project 1 - Your First Web Application

## Project Overview
Build a personal portfolio website with multiple services and learn fundamental Ingress routing patterns. This project introduces you to host-based and path-based routing while creating something you can actually use.

## Business Context
Imagine you're a developer who wants to showcase your work through a personal website that includes:
- Main portfolio site
- Blog section  
- API for contact forms
- Admin area for content management

## Learning Objectives
By the end of this project, you'll be able to:
- Create multi-service applications with different routing needs
- Implement both host-based and path-based Ingress routing
- Handle static content and dynamic APIs through the same Ingress
- Debug common Ingress routing issues
- Understand the relationship between Services and Ingress rules

## Architecture Overview

We'll build:
- **Portfolio Frontend** (static site) - `yourname.dev`
- **Blog Service** (dynamic content) - `blog.yourname.dev` 
- **API Service** (REST endpoints) - `yourname.dev/api/*`
- **Admin Panel** (management interface) - `yourname.dev/admin/*`

## Phase 1: Create the Services

### Portfolio Frontend (Static Site)

```yaml
# portfolio-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: portfolio-config
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Your Portfolio</title>
        <link rel="stylesheet" href="style.css">
    </head>
    <body>
        <header>
            <nav>
                <h1>Your Name</h1>
                <ul>
                    <li><a href="/">Home</a></li>
                    <li><a href="http://blog.yourname.dev">Blog</a></li>
                    <li><a href="/admin">Admin</a></li>
                </ul>
            </nav>
        </header>
        
        <main>
            <section class="hero">
                <h2>Full-Stack Developer & DevOps Engineer</h2>
                <p>Passionate about Kubernetes, cloud technologies, and building scalable applications.</p>
            </section>
            
            <section class="projects">
                <h3>Featured Projects</h3>
                <div class="project-grid">
                    <div class="project-card">
                        <h4>E-commerce Platform</h4>
                        <p>Microservices architecture with Kubernetes Ingress routing</p>
                    </div>
                    <div class="project-card">
                        <h4>Personal Blog</h4>
                        <p>Dynamic content management with API integration</p>
                    </div>
                </div>
            </section>
            
            <section class="contact">
                <h3>Get In Touch</h3>
                <form id="contact-form">
                    <input type="text" id="name" placeholder="Your Name" required>
                    <input type="email" id="email" placeholder="Your Email" required>
                    <textarea id="message" placeholder="Your Message" required></textarea>
                    <button type="submit">Send Message</button>
                </form>
            </section>
        </main>
        
        <script src="script.js"></script>
    </body>
    </html>

  style.css: |
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }
    
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        line-height: 1.6;
        color: #333;
        background: #f4f4f4;
    }
    
    header {
        background: #2c3e50;
        color: white;
        padding: 1rem 0;
        position: sticky;
        top: 0;
        z-index: 100;
    }
    
    nav {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0 2rem;
    }
    
    nav ul {
        list-style: none;
        display: flex;
        gap: 2rem;
    }
    
    nav a {
        color: white;
        text-decoration: none;
        transition: color 0.3s;
    }
    
    nav a:hover {
        color: #3498db;
    }
    
    main {
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
    }
    
    .hero {
        text-align: center;
        padding: 4rem 0;
        background: white;
        border-radius: 8px;
        margin-bottom: 2rem;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    
    .hero h2 {
        color: #2c3e50;
        margin-bottom: 1rem;
    }
    
    .projects {
        margin: 2rem 0;
    }
    
    .project-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 2rem;
        margin-top: 1rem;
    }
    
    .project-card {
        background: white;
        padding: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        transition: transform 0.3s;
    }
    
    .project-card:hover {
        transform: translateY(-5px);
    }
    
    .contact {
        background: white;
        padding: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    
    .contact form {
        display: grid;
        gap: 1rem;
        margin-top: 1rem;
    }
    
    .contact input, .contact textarea {
        padding: 1rem;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-size: 1rem;
    }
    
    .contact button {
        background: #3498db;
        color: white;
        border: none;
        padding: 1rem;
        border-radius: 4px;
        font-size: 1rem;
        cursor: pointer;
        transition: background 0.3s;
    }
    
    .contact button:hover {
        background: #2980b9;
    }

  script.js: |
    document.addEventListener('DOMContentLoaded', function() {
        const contactForm = document.getElementById('contact-form');
        
        contactForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = {
                name: document.getElementById('name').value,
                email: document.getElementById('email').value,
                message: document.getElementById('message').value
            };
            
            try {
                const response = await fetch('/api/contact', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(formData)
                });
                
                if (response.ok) {
                    alert('Message sent successfully!');
                    contactForm.reset();
                } else {
                    alert('Error sending message. Please try again.');
                }
            } catch (error) {
                console.error('Error:', error);
                alert('Error sending message. Please try again.');
            }
        });
    });
```

### Blog Service

```yaml
# blog-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blog-config
data:
  server.js: |
    const express = require('express');
    const app = express();
    const PORT = 3001;
    
    app.use(express.static('public'));
    app.use(express.json());
    
    // Mock blog posts
    const posts = [
        {
            id: 1,
            title: 'Getting Started with Kubernetes Ingress',
            slug: 'kubernetes-ingress-basics',
            excerpt: 'Learn the fundamentals of routing traffic in Kubernetes',
            content: 'Kubernetes Ingress provides HTTP and HTTPS routing to services...',
            date: '2024-01-15',
            author: 'Your Name'
        },
        {
            id: 2,
            title: 'Building Microservices with Node.js',
            slug: 'nodejs-microservices',
            excerpt: 'Design patterns for scalable microservice architectures',
            content: 'Microservices architecture allows teams to develop and deploy...',
            date: '2024-01-10',
            author: 'Your Name'
        }
    ];
    
    // Serve blog homepage
    app.get('/', (req, res) => {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Your Blog</title>
                <link rel="stylesheet" href="/style.css">
            </head>
            <body>
                <header>
                    <nav>
                        <h1>Tech Blog</h1>
                        <a href="http://yourname.dev">← Back to Portfolio</a>
                    </nav>
                </header>
                <main>
                    <h2>Latest Posts</h2>
                    ${posts.map(post => `
                        <article>
                            <h3><a href="/posts/${post.slug}">${post.title}</a></h3>
                            <p class="meta">By ${post.author} on ${post.date}</p>
                            <p>${post.excerpt}</p>
                        </article>
                    `).join('')}
                </main>
            </body>
            </html>
        `);
    });
    
    // Serve individual blog posts
    app.get('/posts/:slug', (req, res) => {
        const post = posts.find(p => p.slug === req.params.slug);
        if (!post) {
            return res.status(404).send('Post not found');
        }
        
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>${post.title} - Your Blog</title>
                <link rel="stylesheet" href="/style.css">
            </head>
            <body>
                <header>
                    <nav>
                        <h1>Tech Blog</h1>
                        <a href="/">← All Posts</a>
                    </nav>
                </header>
                <main>
                    <article>
                        <h1>${post.title}</h1>
                        <p class="meta">By ${post.author} on ${post.date}</p>
                        <div class="content">
                            <p>${post.content}</p>
                        </div>
                    </article>
                </main>
            </body>
            </html>
        `);
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Blog service running on port ${PORT}`);
    });

  package.json: |
    {
      "name": "blog-service",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {
        "express": "^4.18.0"
      }
    }

  public/style.css: |
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
        background: #f9f9f9;
    }
    
    header {
        background: #34495e;
        color: white;
        padding: 1rem;
        border-radius: 8px;
        margin-bottom: 2rem;
    }
    
    nav {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    
    nav a {
        color: #3498db;
        text-decoration: none;
    }
    
    article {
        background: white;
        padding: 2rem;
        margin-bottom: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    
    .meta {
        color: #666;
        font-size: 0.9rem;
        margin-bottom: 1rem;
    }
    
    h3 a {
        color: #2c3e50;
        text-decoration: none;
    }
    
    h3 a:hover {
        color: #3498db;
    }
```

### API Service

```yaml
# api-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  server.js: |
    const express = require('express');
    const cors = require('cors');
    
    const app = express();
    const PORT = 3002;
    
    app.use(cors());
    app.use(express.json());
    
    // Mock database for contact messages
    const messages = [];
    
    // Contact form endpoint
    app.post('/contact', (req, res) => {
        const { name, email, message } = req.body;
        
        if (!name || !email || !message) {
            return res.status(400).json({ error: 'All fields are required' });
        }
        
        const newMessage = {
            id: messages.length + 1,
            name,
            email,
            message,
            timestamp: new Date().toISOString()
        };
        
        messages.push(newMessage);
        
        console.log('New message received:', newMessage);
        
        res.json({ 
            success: true, 
            message: 'Message received successfully',
            id: newMessage.id 
        });
    });
    
    // Get all messages (for admin)
    app.get('/messages', (req, res) => {
        res.json(messages);
    });
    
    // Health check
    app.get('/health', (req, res) => {
        res.json({ 
            status: 'healthy', 
            service: 'api',
            messages_count: messages.length 
        });
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`API service running on port ${PORT}`);
    });

  package.json: |
    {
      "name": "api-service",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {
        "express": "^4.18.0",
        "cors": "^2.8.5"
      }
    }
```

### Admin Panel

```yaml
# admin-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-config
data:
  server.js: |
    const express = require('express');
    const app = express();
    const PORT = 3003;
    
    app.use(express.static('public'));
    app.use(express.json());
    
    // Simple admin interface
    app.get('/', (req, res) => {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Admin Panel</title>
                <link rel="stylesheet" href="/admin.css">
            </head>
            <body>
                <header>
                    <h1>Portfolio Admin</h1>
                    <nav>
                        <a href="http://yourname.dev">← Back to Site</a>
                    </nav>
                </header>
                
                <main>
                    <section>
                        <h2>Contact Messages</h2>
                        <button onclick="loadMessages()">Refresh Messages</button>
                        <div id="messages-container">
                            <p>Click "Refresh Messages" to load contact form submissions</p>
                        </div>
                    </section>
                </main>
                
                <script>
                    async function loadMessages() {
                        try {
                            const response = await fetch('/api/messages');
                            const messages = await response.json();
                            
                            const container = document.getElementById('messages-container');
                            
                            if (messages.length === 0) {
                                container.innerHTML = '<p>No messages yet.</p>';
                                return;
                            }
                            
                            container.innerHTML = messages.map(msg => 
                                '<div class="message-card">' +
                                    '<h3>' + msg.name + '</h3>' +
                                    '<p><strong>Email:</strong> ' + msg.email + '</p>' +
                                    '<p><strong>Message:</strong> ' + msg.message + '</p>' +
                                    '<p><small>Received: ' + new Date(msg.timestamp).toLocaleString() + '</small></p>' +
                                '</div>'
                            ).join('');
                        } catch (error) {
                            console.error('Error loading messages:', error);
                            document.getElementById('messages-container').innerHTML = 
                                '<p style="color: red;">Error loading messages</p>';
                        }
                    }
                </script>
            </body>
            </html>
        `);
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Admin service running on port ${PORT}`);
    });

  public/admin.css: |
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        margin: 0;
        padding: 0;
        background: #f5f5f5;
    }
    
    header {
        background: #e74c3c;
        color: white;
        padding: 1rem 2rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    
    header a {
        color: white;
        text-decoration: none;
    }
    
    main {
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
    }
    
    button {
        background: #3498db;
        color: white;
        border: none;
        padding: 0.75rem 1.5rem;
        border-radius: 4px;
        cursor: pointer;
        margin-bottom: 1rem;
    }
    
    button:hover {
        background: #2980b9;
    }
    
    .message-card {
        background: white;
        padding: 1.5rem;
        margin-bottom: 1rem;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    
    .message-card h3 {
        margin-top: 0;
        color: #2c3e50;
    }
```

## Phase 2: Deploy Services

```bash
# Apply all ConfigMaps
kubectl apply -f portfolio-config.yaml
kubectl apply -f blog-service-config.yaml
kubectl apply -f api-service-config.yaml
kubectl apply -f admin-service-config.yaml

# Deploy all services
kubectl apply -f - <<EOF
# Portfolio Frontend (Static Site)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio
  labels:
    app: portfolio
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portfolio
  template:
    metadata:
      labels:
        app: portfolio
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: portfolio-config
---
apiVersion: v1
kind: Service
metadata:
  name: portfolio-service
spec:
  selector:
    app: portfolio
  ports:
  - port: 80
    targetPort: 80
---
# Blog Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  labels:
    app: blog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      containers:
      - name: blog
        image: node:18-alpine
        command: ['sh', '-c', 'npm install && node server.js']
        ports:
        - containerPort: 3001
        volumeMounts:
        - name: app
          mountPath: /app
        workingDir: /app
      volumes:
      - name: app
        configMap:
          name: blog-config
---
apiVersion: v1
kind: Service
metadata:
  name: blog-service
spec:
  selector:
    app: blog
  ports:
  - port: 80
    targetPort: 3001
---
# API Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: node:18-alpine
        command: ['sh', '-c', 'npm install && node server.js']
        ports:
        - containerPort: 3002
        volumeMounts:
        - name: app
          mountPath: /app
        workingDir: /app
      volumes:
      - name: app
        configMap:
          name: api-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 3002
---
# Admin Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin
  labels:
    app: admin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin
  template:
    metadata:
      labels:
        app: admin
    spec:
      containers:
      - name: admin
        image: node:18-alpine
        command: ['sh', '-c', 'npm install express && node server.js']
        ports:
        - containerPort: 3003
        volumeMounts:
        - name: app
          mountPath: /app
        workingDir: /app
      volumes:
      - name: app
        configMap:
          name: admin-config
---
apiVersion: v1
kind: Service
metadata:
  name: admin-service
spec:
  selector:
    app: admin
  ports:
  - port: 80
    targetPort: 3003
EOF
```

## Phase 3: Configure Ingress Routing

Here's where the magic happens - routing different requests to different services:

```yaml
# portfolio-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portfolio-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  # Main portfolio site
  - host: yourname.dev
    http:
      paths:
      # API routes (must come first - more specific)
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      # Admin routes
      - path: /admin(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
      # Main site (catch-all, must be last)
      - path: /
        pathType: Prefix
        backend:
          service:
            name: portfolio-service
            port:
              number: 80
  
  # Blog subdomain
  - host: blog.yourname.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

Apply the Ingress:

```bash
kubectl apply -f portfolio-ingress.yaml
```

## Phase 4: Set Up Local DNS and Test

```bash
# Get minikube IP
MINIKUBE_IP=$(minikube ip)

# Add entries to hosts file
echo "$MINIKUBE_IP yourname.dev" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP blog.yourname.dev" | sudo tee -a /etc/hosts

# Test each route
echo "Testing main site..."
curl -s http://yourname.dev | grep -o "<title>.*</title>"

echo "Testing blog..."
curl -s http://blog.yourname.dev | grep -o "<title>.*</title>"

echo "Testing API health..."
curl -s http://yourname.dev/api/health | jq .

echo "Testing admin panel..."
curl -s http://yourname.dev/admin | grep -o "<title>.*</title>"
```

## Phase 5: Interactive Testing

Open your browser and visit:

1. **http://yourname.dev** - Main portfolio
2. **http://blog.yourname.dev** - Blog section
3. **http://yourname.dev/admin** - Admin panel
4. **http://yourname.dev/api/health** - API health check

### Test the Contact Form
1. Go to **http://yourname.dev**
2. Fill out the contact form at the bottom
3. Submit the form (it should show "Message sent successfully!")
4. Go to **http://yourname.dev/admin**
5. Click "Refresh Messages" to see your submission

## Understanding the Routing

Let's break down what's happening:

### Host-based Routing
- `yourname.dev` → Portfolio service
- `blog.yourname.dev` → Blog service

### Path-based Routing  
- `yourname.dev/api/*` → API service
- `yourname.dev/admin/*` → Admin service
- `yourname.dev/*` → Portfolio service (catch-all)

### The `rewrite-target` Annotation
```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
```
This rewrites `/api/health` to `/health` when forwarding to the API service.

## Phase 6: Troubleshooting and Debugging

### Check Ingress Status
```bash
# View Ingress details
kubectl describe ingress portfolio-ingress

# Check endpoints
kubectl get endpoints

# View Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common Issues and Solutions

**Issue**: 404 Not Found for all routes
**Solution**: Check that Ingress controller is running
```bash
kubectl get pods -n ingress-nginx
```

**Issue**: API routes return 404
**Solution**: Verify path order in Ingress (more specific paths first)

**Issue**: Contact form doesn't work
**Solution**: Check browser console for CORS errors, verify API service is running

## Phase 7: Adding Features

### Add HTTPS (Optional)
```yaml
# Add to Ingress metadata.annotations:
cert-manager.io/cluster-issuer: "selfsigned-issuer"

# Add to Ingress spec:
tls:
- hosts:
  - yourname.dev
  - blog.yourname.dev
  secretName: portfolio-tls
```

### Add Request Logging
```yaml
# Add to Ingress annotations:
nginx.ingress.kubernetes.io/configuration-snippet: |
  access_log /var/log/nginx/portfolio.access.log;
```

## Project Summary

You've successfully built a multi-service personal portfolio that demonstrates:

✅ **Host-based routing** - Different subdomains for different services  
✅ **Path-based routing** - Different paths within the same domain  
✅ **Static and dynamic content** - HTML files and Node.js APIs  
✅ **Cross-service communication** - Frontend calling API endpoints  
✅ **Real-world application structure** - Separate concerns (frontend, API, admin)

## Self-Assessment Questions

Before moving to Unit 4, ensure you understand:

1. **What's the difference between host-based and path-based routing?**
2. **Why does path order matter in Ingress rules?**
3. **How does the `rewrite-target` annotation work?**
4. **When would you choose subdomains vs. path-based routing?**

## Clean-up

```bash
# Delete all resources
kubectl delete ingress portfolio-ingress
kubectl delete service portfolio-service blog-service api-service admin-service
kubectl delete deployment portfolio blog api admin
kubectl delete configmap portfolio-config blog-config api-config admin-config

# Remove from hosts file
sudo sed -i '/yourname.dev/d' /etc/hosts
sudo sed -i '/blog.yourname.dev/d' /etc/hosts
```

## Preparing for Unit 4

In the next unit, we'll explore multi-service architectures. Think about:
1. How would you handle authentication across multiple services?
2. What happens when services need to communicate with each other?
3. How do you manage configurations across different environments?

---

# Unit 4: Multi-Service Architecture Patterns

*Note: This unit's detailed content needs to be developed based on the course progression*

## Learning Objectives
- Design routing for microservice architectures
- Implement service-to-service communication patterns
- Handle authentication and authorization across services
- Manage configuration and secrets
- Implement health checks and monitoring

## Key Concepts to Cover
- **Microservice Communication** - Service mesh vs Ingress routing
- **Authentication Patterns** - JWT tokens, OAuth2, service accounts
- **Configuration Management** - ConfigMaps, Secrets, environment-specific configs
- **Health Checks** - Readiness and liveness probes
- **Monitoring and Observability** - Logging, metrics, tracing

---

# Unit 5: Secure HTTPS Setup with TLS

*Note: This unit's detailed content needs to be developed based on the course progression*

## Learning Objectives  
- Configure TLS termination at the Ingress level
- Implement automatic certificate management
- Set up proper security headers
- Handle mixed content and CORS issues
- Implement security best practices

## Key Concepts to Cover
- **TLS Termination** - SSL/TLS certificates, SNI
- **Certificate Management** - cert-manager, Let's Encrypt, self-signed certificates
- **Security Headers** - HSTS, CSP, X-Frame-Options
- **CORS Configuration** - Cross-origin requests, preflight handling
- **Security Best Practices** - Rate limiting, IP whitelisting

---

# Unit 6: Mini-Project 4 - Real-World E-commerce Platform

## Project Overview
In this unit, we'll build a comprehensive e-commerce platform that demonstrates advanced Ingress patterns used in production systems. You'll learn to handle complex routing scenarios, implement authentication flows, manage session persistence, and optimize for performance at scale.

## Business Context and Requirements

Imagine you're the platform engineer for "TechBooks" - a specialized online bookstore. The business has these requirements:

**Customer Experience**:
- Fast, responsive storefront
- Personalized recommendations  
- Secure checkout process
- Mobile app support

**Business Operations**:
- Admin dashboard for inventory
- Analytics and reporting
- Vendor portal for suppliers
- Customer service tools

**Technical Requirements**:
- Handle 10,000+ concurrent users
- 99.9% uptime SLA
- PCI DSS compliance for payments
- Global CDN integration
- A/B testing capability

## Pre-Project Analysis

Based on your experience with the previous units:

1. **What new Ingress challenges might arise with user authentication and sessions?**
2. **How would you handle different user types (customers, admins, vendors) accessing the same domain?**
3. **What routing strategies would you use for A/B testing?**
4. **How might payment processing affect your Ingress configuration?**

## Learning Objectives

By the end of this project, you'll be able to:
- Design complex routing architectures for real-world applications
- Implement authentication-aware routing patterns
- Configure session affinity and load balancing strategies
- Handle multiple API versions and backwards compatibility
- Implement feature flags and A/B testing through routing
- Optimize Ingress for high-performance scenarios

## Architecture Overview

Our e-commerce platform will consist of:

### Frontend Services
- **Storefront** (`www.techbooks.com`) - Customer shopping experience
- **Mobile API** (`m.techbooks.com`) - Mobile app endpoints
- **Admin Portal** (`admin.techbooks.com`) - Business management
- **Vendor Portal** (`vendors.techbooks.com`) - Supplier interface

### Backend Services  
- **User Service** - Authentication and user management
- **Catalog Service** - Product information and search
- **Cart Service** - Shopping cart management (stateful)
- **Order Service** - Order processing and fulfillment
- **Payment Service** - Payment processing
- **Analytics Service** - Business intelligence

### Supporting Services
- **CDN Integration** - Static asset delivery
- **Search Service** - Product search and filtering
- **Recommendation Engine** - Personalized suggestions
- **Notification Service** - Email and SMS

## Phase 1: Core Service Development

Let's start by creating the foundational services:

### User Authentication Service

This service will handle login, registration, and session management:

```yaml
# user-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-service-config
data:
  server.js: |
    const express = require('express');
    const cors = require('cors');
    const jwt = require('jsonwebtoken');
    
    const app = express();
    const PORT = 3001;
    const JWT_SECRET = 'demo-secret-change-in-production';
    
    app.use(cors({
        origin: ['https://www.techbooks.com', 'https://m.techbooks.com', 'https://admin.techbooks.com'],
        credentials: true
    }));
    app.use(express.json());
    
    // Mock user database
    const users = {
        'customer@example.com': { id: 1, email: 'customer@example.com', role: 'customer', password: 'demo123' },
        'admin@techbooks.com': { id: 2, email: 'admin@techbooks.com', role: 'admin', password: 'admin123' },
        'vendor@supplier.com': { id: 3, email: 'vendor@supplier.com', role: 'vendor', password: 'vendor123' }
    };
    
    // Authentication endpoints
    app.post('/auth/login', (req, res) => {
        const { email, password } = req.body;
        const user = users[email];
        
        if (!user || user.password !== password) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = jwt.sign(
            { userId: user.id, email: user.email, role: user.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({
            message: 'Login successful',
            token,
            user: { id: user.id, email: user.email, role: user.role }
        });
    });
    
    app.post('/auth/validate', (req, res) => {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token provided' });
        }
        
        const token = authHeader.substring(7);
        
        try {
            const decoded = jwt.verify(token, JWT_SECRET);
            res.json({ valid: true, user: decoded });
        } catch (error) {
            res.status(401).json({ error: 'Invalid token' });
        }
    });
    
    app.get('/auth/profile', (req, res) => {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token provided' });
        }
        
        try {
            const token = authHeader.substring(7);
            const decoded = jwt.verify(token, JWT_SECRET);
            const user = users[decoded.email];
            
            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }
            
            res.json({
                id: user.id,
                email: user.email,
                role: user.role,
                preferences: {
                    theme: 'light',
                    notifications: true
                }
            });
        } catch (error) {
            res.status(401).json({ error: 'Invalid token' });
        }
    });
    
    app.get('/health', (req, res) => {
        res.json({ status: 'healthy', service: 'user-service' });
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`User service running on port ${PORT}`);
    });
```

### Product Catalog Service

```yaml
# catalog-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog-service-config
data:
  server.js: |
    const express = require('express');
    const cors = require('cors');
    
    const app = express();
    const PORT = 3002;
    
    app.use(cors());
    app.use(express.json());
    
    // Mock product database
    const products = [
        {
            id: 1,
            title: 'Kubernetes in Action, 2nd Edition',
            author: 'Marko Luksa',
            price: 49.99,
            category: 'DevOps',
            stock: 150,
            description: 'Comprehensive guide to Kubernetes',
            image: '/images/k8s-action.jpg',
            featured: true
        },
        {
            id: 2,
            title: 'Site Reliability Engineering',
            author: 'Google SRE Team',
            price: 39.99,
            category: 'SRE',
            stock: 200,
            description: 'Google\'s approach to service reliability',
            image: '/images/sre-book.jpg',
            featured: true
        },
        {
            id: 3,
            title: 'Building Microservices',
            author: 'Sam Newman',
            price: 44.99,
            category: 'Architecture',
            stock: 75,
            description: 'Designing fine-grained systems',
            image: '/images/microservices.jpg',
            featured: false
        }
    ];
    
    // Product endpoints
    app.get('/products', (req, res) => {
        const { category, featured, search, limit = 10, offset = 0 } = req.query;
        let filteredProducts = [...products];
        
        if (category) {
            filteredProducts = filteredProducts.filter(p => 
                p.category.toLowerCase() === category.toLowerCase()
            );
        }
        
        if (featured === 'true') {
            filteredProducts = filteredProducts.filter(p => p.featured);
        }
        
        if (search) {
            filteredProducts = filteredProducts.filter(p => 
                p.title.toLowerCase().includes(search.toLowerCase()) ||
                p.author.toLowerCase().includes(search.toLowerCase())
            );
        }
        
        const total = filteredProducts.length;
        const paginatedProducts = filteredProducts.slice(
            parseInt(offset), 
            parseInt(offset) + parseInt(limit)
        );
        
        res.json({
            products: paginatedProducts,
            total,
            limit: parseInt(limit),
            offset: parseInt(offset)
        });
    });
    
    app.get('/products/:id', (req, res) => {
        const product = products.find(p => p.id === parseInt(req.params.id));
        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }
        res.json(product);
    });
    
    app.get('/categories', (req, res) => {
        const categories = [...new Set(products.map(p => p.category))];
        res.json(categories);
    });
    
    app.get('/health', (req, res) => {
        res.json({ status: 'healthy', service: 'catalog-service' });
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Catalog service running on port ${PORT}`);
    });
```

### Shopping Cart Service (Stateful)

```yaml
# cart-service-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cart-service-config
data:
  server.js: |
    const express = require('express');
    const cors = require('cors');
    
    const app = express();
    const PORT = 3003;
    
    app.use(cors());
    app.use(express.json());
    
    // In-memory cart storage (in production, use Redis or database)
    const carts = {};
    
    // Middleware to extract user ID from token (simplified)
    const extractUserId = (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            // In production, validate the JWT token
            req.userId = 'demo-user-' + Math.floor(Math.random() * 1000);
        } else {
            req.userId = 'anonymous-' + req.ip;
        }
        next();
    };
    
    app.use(extractUserId);
    
    // Cart endpoints
    app.get('/', (req, res) => {
        const cart = carts[req.userId] || { items: [], total: 0 };
        res.json(cart);
    });
    
    app.post('/add', (req, res) => {
        const { productId, quantity = 1, price, title } = req.body;
        
        if (!carts[req.userId]) {
            carts[req.userId] = { items: [], total: 0 };
        }
        
        const cart = carts[req.userId];
        const existingItem = cart.items.find(item => item.productId === productId);
        
        if (existingItem) {
            existingItem.quantity += quantity;
        } else {
            cart.items.push({ productId, quantity, price, title });
        }
        
        // Recalculate total
        cart.total = cart.items.reduce((total, item) => 
            total + (item.price * item.quantity), 0
        );
        
        res.json({
            message: 'Item added to cart',
            cart: cart
        });
    });
    
    app.delete('/remove/:productId', (req, res) => {
        if (!carts[req.userId]) {
            return res.status(404).json({ error: 'Cart not found' });
        }
        
        const cart = carts[req.userId];
        cart.items = cart.items.filter(item => 
            item.productId !== parseInt(req.params.productId)
        );
        
        cart.total = cart.items.reduce((total, item) => 
            total + (item.price * item.quantity), 0
        );
        
        res.json({
            message: 'Item removed from cart',
            cart: cart
        });
    });
    
    app.post('/clear', (req, res) => {
        carts[req.userId] = { items: [], total: 0 };
        res.json({ message: 'Cart cleared' });
    });
    
    app.get('/health', (req, res) => {
        res.json({ status: 'healthy', service: 'cart-service' });
    });
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Cart service running on port ${PORT}`);
    });
```

### Deploy Core Services

```bash
# Create all service configs
kubectl apply -f user-service-config.yaml
kubectl apply -f catalog-service-config.yaml  
kubectl apply -f cart-service-config.yaml

# Create deployments and services
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels:
    app: techbooks
    component: user-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: techbooks
      component: user-service
  template:
    metadata:
      labels:
        app: techbooks
        component: user-service
    spec:
      containers:
      - name: user-service
        image: node:18-alpine
        command: ['sh', '-c', 'npm init -y && npm install express cors jsonwebtoken && node server.js']
        ports:
        - containerPort: 3001
        volumeMounts:
        - name: config
          mountPath: /app
        workingDir: /app
        env:
        - name: NODE_ENV
          value: "production"
      volumes:
      - name: config
        configMap:
          name: user-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  selector:
    app: techbooks
    component: user-service
  ports:
  - port: 3001
    targetPort: 3001
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service
  labels:
    app: techbooks
    component: catalog-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: techbooks
      component: catalog-service
  template:
    metadata:
      labels:
        app: techbooks
        component: catalog-service
    spec:
      containers:
      - name: catalog-service
        image: node:18-alpine
        command: ['sh', '-c', 'npm init -y && npm install express cors && node server.js']
        ports:
        - containerPort: 3002
        volumeMounts:
        - name: config
          mountPath: /app
        workingDir: /app
      volumes:
      - name: config
        configMap:
          name: catalog-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
spec:
  selector:
    app: techbooks
    component: catalog-service
  ports:
  - port: 3002
    targetPort: 3002
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cart-service
  labels:
    app: techbooks
    component: cart-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: techbooks
      component: cart-service
  template:
    metadata:
      labels:
        app: techbooks
        component: cart-service
    spec:
      containers:
      - name: cart-service
        image: node:18-alpine
        command: ['sh', '-c', 'npm init -y && npm install express cors && node server.js']
        ports:
        - containerPort: 3003
        volumeMounts:
        - name: config
          mountPath: /app
        workingDir: /app
      volumes:
      - name: config
        configMap:
          name: cart-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: cart-service
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "cart-session"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
spec:
  selector:
    app: techbooks
    component: cart-service
  ports:
  - port: 3003
    targetPort: 3003
EOF
```

**Important Note**: Notice the session affinity annotations on the cart service. This ensures users stick to the same pod for cart consistency.

## Phase 2: Frontend Applications

Now let's create the customer-facing applications:

### Main Storefront

```yaml
# storefront-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storefront-config
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TechBooks - Your Technical Bookstore</title>
        <link rel="stylesheet" href="styles.css">
    </head>
    <body>
        <nav class="navbar">
            <div class="nav-container">
                <h1 class="logo">📚 TechBooks</h1>
                <div class="nav-menu">
                    <a href="#" onclick="showSection('home')">Home</a>
                    <a href="#" onclick="showSection('products')">Browse</a>
                    <a href="#" onclick="showSection('cart')">Cart (<span id="cart-count">0</span>)</a>
                    <div class="user-menu">
                        <span id="user-info">Guest</span>
                        <button id="login-btn" onclick="showSection('login')">Login</button>
                        <button id="logout-btn" onclick="logout()" style="display:none">Logout</button>
                    </div>
                </div>
            </div>
        </nav>

        <main class="container">
            <!-- Home Section -->
            <section id="home" class="section active">
                <div class="hero">
                    <h2>Discover the Best Technical Books</h2>
                    <p>From Kubernetes to SRE, find the knowledge you need to advance your career</p>
                    <button class="cta-button" onclick="loadProducts()">Browse Books</button>
                </div>
                
                <div class="featured-products">
                    <h3>Featured Books</h3>
                    <div id="featured-list" class="product-grid"></div>
                </div>
            </section>

            <!-- Products Section -->
            <section id="products" class="section">
                <div class="filters">
                    <h3>Browse Books</h3>
                    <div class="filter-controls">
                        <select id="category-filter" onchange="filterProducts()">
                            <option value="">All Categories</option>
                        </select>
                        <input type="text" id="search-input" placeholder="Search books..." onkeyup="searchProducts()">
                    </div>
                </div>
                <div id="products-list" class="product-grid"></div>
                <div class="pagination">
                    <button id="prev-page" onclick="changePage(-1)">Previous</button>
                    <span id="page-info">Page 1</span>
                    <button id="next-page" onclick="changePage(1)">Next</button>
                </div>
            </section>

            <!-- Cart Section -->
            <section id="cart" class="section">
                <h3>Shopping Cart</h3>
                <div id="cart-items"></div>
                <div class="cart-summary">
                    <div class="total">Total: $<span id="cart-total">0.00</span></div>
                    <button class="checkout-btn" onclick="checkout()">Proceed to Checkout</button>
                </div>
            </section>

            <!-- Login Section -->
            <section id="login" class="section">
                <h3>Login to Your Account</h3>
                <form id="login-form" onsubmit="login(event)">
                    <div class="form-group">
                        <label>Email:</label>
                        <input type="email" id="email" required>
                        <small>Demo accounts: customer@example.com, admin@techbooks.com</small>
                    </div>
                    <div class="form-group">
                        <label>Password:</label>
                        <input type="password" id="password" required>
                        <small>Use: demo123, admin123, or vendor123</small>
                    </div>
                    <button type="submit">Login</button>
                </form>
            </section>
        </main>

        <footer>
            <p>&copy; 2024 TechBooks. All rights reserved.</p>
            <div class="admin-links">
                <a href="https://admin.techbooks.com">Admin Portal</a> |
                <a href="https://vendors.techbooks.com">Vendor Portal</a>
            </div>
        </footer>

        <script src="app.js"></script>
    </body>
    </html>

  styles.css: |
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; }
    
    .navbar { background: #2c3e50; color: white; padding: 1rem 0; position: sticky; top: 0; z-index: 100; }
    .nav-container { max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; padding: 0 2rem; }
    .logo { font-size: 1.5rem; }
    .nav-menu { display: flex; align-items: center; gap: 2rem; }
    .nav-menu a { color: white; text-decoration: none; transition: color 0.3s; }
    .nav-menu a:hover { color: #3498db; }
    .user-menu { display: flex; align-items: center; gap: 1rem; }
    
    .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
    .section { display: none; }
    .section.active { display: block; }
    
    .hero { text-align: center; padding: 4rem 0; background: white; border-radius: 8px; margin-bottom: 2rem; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .hero h2 { color: #2c3e50; margin-bottom: 1rem; }
    .cta-button { background: #3498db; color: white; padding: 1rem 2rem; border: none; border-radius: 4px; font-size: 1.1rem; cursor: pointer; transition: background 0.3s; }
    .cta-button:hover { background: #2980b9; }
    
    .product-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 2rem; }
    .product-card { background: white; border-radius: 8px; padding: 1.5rem; box-shadow: 0 2px 10px rgba(0,0,0,0.1); transition: transform 0.3s; }
    .product-card:hover { transform: translateY(-5px); }
    .product-card h4 { color: #2c3e50; margin-bottom: 0.5rem; }
    .product-card .author { color: #7f8c8d; margin-bottom: 1rem; }
    .product-card .price { font-size: 1.2rem; font-weight: bold; color: #27ae60; margin-bottom: 1rem; }
    .product-card button { background: #27ae60; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 4px; cursor: pointer; width: 100%; }
    .product-card button:hover { background: #229954; }
    
    .filters { background: white; padding: 1.5rem; border-radius: 8px; margin-bottom: 2rem; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .filter-controls { display: flex; gap: 1rem; margin-top: 1rem; }
    .filter-controls select, .filter-controls input { padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; flex: 1; }
    
    .pagination { text-align: center; margin-top: 2rem; }
    .pagination button { background: #3498db; color: white; border: none; padding: 0.75rem 1.5rem; margin: 0 0.5rem; border-radius: 4px; cursor: pointer; }
    .pagination button:disabled { background: #bdc3c7; cursor: not-allowed; }
    
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.5rem; font-weight: bold; }
    .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #ddd; border-radius: 4px; }
    .form-group small { color: #7f8c8d; font-size: 0.85rem; }
    
    .cart-summary { background: white; padding: 1.5rem; border-radius: 8px; margin-top: 2rem; text-align: center; }
    .total { font-size: 1.5rem; font-weight: bold; margin-bottom: 1rem; }
    .checkout-btn { background: #e74c3c; color: white; border: none; padding: 1rem 2rem; font-size: 1.1rem; border-radius: 4px; cursor: pointer; }
    
    footer { background: #34495e; color: white; text-align: center; padding: 2rem; margin-top: 2rem; }
    footer a { color: #3498db; text-decoration: none; }

  app.js: |
    // Global state
    let currentUser = null;
    let currentPage = 0;
    let products = [];
    let cart = { items: [], total: 0 };
    const pageSize = 6;
    
    // Initialize app
    document.addEventListener('DOMContentLoaded', function() {
        checkAuthStatus();
        loadFeaturedProducts();
        loadCategories();
        loadCart();
    });
    
    // Navigation
    function showSection(sectionName) {
        document.querySelectorAll('.section').forEach(section => {
            section.classList.remove('active');
        });
        document.getElementById(sectionName).classList.add('active');
        
        if (sectionName === 'products') {
            loadProducts();
        }
    }
    
    // Authentication
    async function checkAuthStatus() {
        const token = localStorage.getItem('authToken');
        if (token) {
            try {
                const response = await fetch('/api/user/auth/profile', {
                    headers: {
                        'Authorization': `Bearer ${token}`
                    }
                });
                
                if (response.ok) {
                    const userData = await response.json();
                    currentUser = userData;
                    updateUserInterface();
                }
            } catch (error) {
                console.error('Auth check failed:', error);
                localStorage.removeItem('authToken');
            }
        }
    }
    
    async function login(event) {
        event.preventDefault();
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        
        try {
            const response = await fetch('/api/user/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });
            
            if (response.ok) {
                const data = await response.json();
                localStorage.setItem('authToken', data.token);
                currentUser = data.user;
                updateUserInterface();
                showSection('home');
                alert('Login successful!');
            } else {
                const error = await response.json();
                alert('Login failed: ' + error.error);
            }
        } catch (error) {
            alert('Login failed: ' + error.message);
        }
    }
    
    function logout() {
        localStorage.removeItem('authToken');
        currentUser = null;
        updateUserInterface();
        alert('Logged out successfully');
    }
    
    function updateUserInterface() {
        const userInfo = document.getElementById('user-info');
        const loginBtn = document.getElementById('login-btn');
        const logoutBtn = document.getElementById('logout-btn');
        
        if (currentUser) {
            userInfo.textContent = `Welcome, ${currentUser.email}`;
            loginBtn.style.display = 'none';
            logoutBtn.style.display = 'block';
        } else {
            userInfo.textContent = 'Guest';
            loginBtn.style.display = 'block';
            logoutBtn.style.display = 'none';
        }
    }
    
    // Product functions
    async function loadFeaturedProducts() {
        try {
            const response = await fetch('/api/catalog/products?featured=true&limit=3');
            const data = await response.json();
            displayProducts(data.products, 'featured-list');
        } catch (error) {
            console.error('Failed to load featured products:', error);
        }
    }
    
    async function loadProducts() {
        try {
            const category = document.getElementById('category-filter')?.value || '';
            const search = document.getElementById('search-input')?.value || '';
            
            let url = `/api/catalog/products?limit=${pageSize}&offset=${currentPage * pageSize}`;
            if (category) url += `&category=${encodeURIComponent(category)}`;
            if (search) url += `&search=${encodeURIComponent(search)}`;
            
            const response = await fetch(url);
            const data = await response.json();
            
            products = data.products;
            displayProducts(products, 'products-list');
            updatePagination(data.total);
        } catch (error) {
            console.error('Failed to load products:', error);
        }
    }
    
    async function loadCategories() {
        try {
            const response = await fetch('/api/catalog/categories');
            const categories = await response.json();
            
            const categoryFilter = document.getElementById('category-filter');
            if (categoryFilter) {
                categories.forEach(category => {
                    const option = document.createElement('option');
                    option.value = category;
                    option.textContent = category;
                    categoryFilter.appendChild(option);
                });
            }
        } catch (error) {
            console.error('Failed to load categories:', error);
        }
    }
    
    function displayProducts(productList, containerId) {
        const container = document.getElementById(containerId);
        if (!container) return;
        
        container.innerHTML = '';
        
        productList.forEach(product => {
            const productCard = document.createElement('div');
            productCard.className = 'product-card';
            productCard.innerHTML = `
                <h4>${product.title}</h4>
                <p class="author">by ${product.author}</p>
                <p class="price">${product.price.toFixed(2)}</p>
                <p>${product.description}</p>
                <button onclick="addToCart(${product.id}, '${product.title}', ${product.price})">
                    Add to Cart
                </button>
            `;
            container.appendChild(productCard);
        });
    }
    
    // Cart functions
    async function addToCart(productId, title, price) {
        try {
            const response = await fetch('/api/cart/add', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': currentUser ? `Bearer ${localStorage.getItem('authToken')}` : ''
                },
                body: JSON.stringify({
                    productId: productId,
                    quantity: 1,
                    price: price,
                    title: title
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                cart = data.cart;
                updateCartDisplay();
                alert(`${title} added to cart!`);
            }
        } catch (error) {
            console.error('Failed to add to cart:', error);
        }
    }
    
    async function loadCart() {
        try {
            const response = await fetch('/api/cart', {
                headers: {
                    'Authorization': currentUser ? `Bearer ${localStorage.getItem('authToken')}` : ''
                }
            });
            
            if (response.ok) {
                cart = await response.json();
                updateCartDisplay();
            }
        } catch (error) {
            console.error('Failed to load cart:', error);
        }
    }
    
    function updateCartDisplay() {
        const cartCount = document.getElementById('cart-count');
        const cartItems = document.getElementById('cart-items');
        const cartTotal = document.getElementById('cart-total');
        
        if (cartCount) {
            cartCount.textContent = cart.items ? cart.items.length : 0;
        }
        
        if (cartTotal) {
            cartTotal.textContent = cart.total ? cart.total.toFixed(2) : '0.00';
        }
        
        if (cartItems) {
            cartItems.innerHTML = '';
            if (cart.items && cart.items.length > 0) {
                cart.items.forEach(item => {
                    const itemDiv = document.createElement('div');
                    itemDiv.className = 'cart-item';
                    itemDiv.innerHTML = `
                        <div style="background: white; padding: 1rem; margin-bottom: 1rem; border-radius: 4px; display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <h4>${item.title}</h4>
                                <p>Quantity: ${item.quantity} | Price: ${item.price.toFixed(2)}</p>
                            </div>
                            <button onclick="removeFromCart(${item.productId})" style="background: #e74c3c; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer;">
                                Remove
                            </button>
                        </div>
                    `;
                    cartItems.appendChild(itemDiv);
                });
            } else {
                cartItems.innerHTML = '<p style="text-align: center; color: #7f8c8d;">Your cart is empty</p>';
            }
        }
    }
    
    async function removeFromCart(productId) {
        try {
            const response = await fetch(`/api/cart/remove/${productId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': currentUser ? `Bearer ${localStorage.getItem('authToken')}` : ''
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                cart = data.cart;
                updateCartDisplay();
            }
        } catch (error) {
            console.error('Failed to remove from cart:', error);
        }
    }
    
    function checkout() {
        if (!cart.items || cart.items.length === 0) {
            alert('Your cart is empty!');
            return;
        }
        
        if (!currentUser) {
            alert('Please login to proceed with checkout');
            showSection('login');
            return;
        }
        
        // In a real app, this would redirect to a secure checkout process
        alert(`Checkout would proceed with total: ${cart.total.toFixed(2)}\n\nIn a real application, this would integrate with a payment processor.`);
    }
    
    // Utility functions
    function filterProducts() {
        currentPage = 0;
        loadProducts();
    }
    
    function searchProducts() {
        currentPage = 0;
        loadProducts();
    }
    
    function changePage(direction) {
        const newPage = currentPage + direction;
        if (newPage >= 0) {
            currentPage = newPage;
            loadProducts();
        }
    }
    
    function updatePagination(total) {
        const pageInfo = document.getElementById('page-info');
        const prevBtn = document.getElementById('prev-page');
        const nextBtn = document.getElementById('next-page');
        
        if (pageInfo) {
            pageInfo.textContent = `Page ${currentPage + 1}`;
        }
        
        if (prevBtn) {
            prevBtn.disabled = currentPage === 0;
        }
        
        if (nextBtn) {
            nextBtn.disabled = (currentPage + 1) * pageSize >= total;
        }
    }
```

### Deploy Storefront

```bash
kubectl apply -f storefront-config.yaml

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  labels:
    app: techbooks
    component: storefront
spec:
  replicas: 3
  selector:
    matchLabels:
      app: techbooks
      component: storefront
  template:
    metadata:
      labels:
        app: techbooks
        component: storefront
    spec:
      containers:
      - name: storefront
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: storefront-config
---
apiVersion: v1
kind: Service
metadata:
  name: storefront-service
spec:
  selector:
    app: techbooks
    component: storefront
  ports:
  - port: 80
    targetPort: 80
EOF
```

## Phase 3: Advanced Ingress Configuration

Now let's create a sophisticated Ingress configuration that handles our complex routing requirements:

```yaml
# techbooks-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: techbooks-ingress
  annotations:
    # SSL and Security
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
    
    # Security Headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # CORS Configuration
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://www.techbooks.com, https://m.techbooks.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    
    # Load Balancing and Session Affinity
    nginx.ingress.kubernetes.io/upstream-hash-by: "$cookie_session_id"
    
    # Rate Limiting
    nginx.ingress.kubernetes.io/rate-limit-rps: "100"
    nginx.ingress.kubernetes.io/rate-limit-connections: "10"
    
    # Caching for Static Assets
    nginx.ingress.kubernetes.io/server-snippet: |
      location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
      }
    
    # URL Rewriting for API endpoints
    nginx.ingress.kubernetes.io/rewrite-target: /$2

spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www.techbooks.com
    - m.techbooks.com
    - admin.techbooks.com
    - vendors.techbooks.com
    secretName: techbooks-tls
  
  rules:
  # Main storefront with API proxy
  - host: www.techbooks.com
    http:
      paths:
      # User service endpoints
      - path: /api/user(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      
      # Catalog service endpoints  
      - path: /api/catalog(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 3002
      
      # Cart service endpoints (with session affinity)
      - path: /api/cart(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: cart-service
            port:
              number: 3003
      
      # Health checks
      - path: /health
        pathType: Exact
        backend:
          service:
            name: storefront-service
            port:
              number: 80
      
      # Main storefront (must be last - catch-all)
      - path: /
        pathType: Prefix
        backend:
          service:
            name: storefront-service
            port:
              number: 80
  
  # Mobile API endpoint
  - host: m.techbooks.com
    http:
      paths:
      # Optimized mobile endpoints
      - path: /api/user(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/catalog(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 3002
      - path: /api/cart(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: cart-service
            port:
              number: 3003
      # Mobile-specific responses (could be different service)
      - path: /
        pathType: Prefix
        backend:
          service:
            name: storefront-service
            port:
              number: 80
```

**Configuration Highlights**:
- **Session Affinity**: Cart service maintains user sessions
- **Rate Limiting**: Protects against abuse
- **Static Asset Caching**: Improves performance
- **Security Headers**: Production-ready security
- **Multi-domain Support**: Main site and mobile optimized

## Phase 4: Admin and Vendor Portals

Let's add the admin and vendor interfaces:

```yaml
# admin-portal-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-portal-config
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>TechBooks Admin Portal</title>
        <link rel="stylesheet" href="styles.css">
    </head>
    <body>
        <nav class="admin-nav">
            <h1>🔧 TechBooks Admin</h1>
            <div class="nav-links">
                <a href="#" onclick="showSection('dashboard')">Dashboard</a>
                <a href="#" onclick="showSection('products')">Products</a>
                <a href="#" onclick="showSection('orders')">Orders</a>
                <a href="#" onclick="showSection('users')">Users</a>
                <a href="https://www.techbooks.com">View Store</a>
            </div>
        </nav>
        
        <main class="admin-content">
            <section id="dashboard" class="admin-section active">
                <h2>Dashboard</h2>
                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>Total Products</h3>
                        <div class="metric-value" id="total-products">-</div>
                    </div>
                    <div class="metric-card">
                        <h3>Active Users</h3>
                        <div class="metric-value">1,234</div>
                    </div>
                    <div class="metric-card">
                        <h3>Orders Today</h3>
                        <div class="metric-value">56</div>
                    </div>
                    <div class="metric-card">
                        <h3>Revenue</h3>
                        <div class="metric-value">$12,456</div>
                    </div>
                </div>
            </section>
            
            <section id="products" class="admin-section">
                <h2>Product Management</h2>
                <button onclick="loadProducts()" class="refresh-btn">Refresh Products</button>
                <div id="admin-products-list"></div>
            </section>
            
            <section id="orders" class="admin-section">
                <h2>Order Management</h2>
                <p>Order management functionality would be implemented here.</p>
                <div class="demo-orders">
                    <div class="order-card">
                        <h4>Order #1001</h4>
                        <p>Customer: customer@example.com</p>
                        <p>Total: $49.99</p>
                        <p>Status: Processing</p>
                    </div>
                    <div class="order-card">
                        <h4>Order #1002</h4>
                        <p>Customer: another@example.com</p>
                        <p>Total: $89.98</p>
                        <p>Status: Shipped</p>
                    </div>
                </div>
            </section>
            
            <section id="users" class="admin-section">
                <h2>User Management</h2>
                <button onclick="loadUserProfile()" class="refresh-btn">Load Current User</button>
                <div id="user-info"></div>
            </section>
        </main>
        
        <script src="app.js"></script>
    </body>
    </html>

  styles.css: |
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f8f9fa; }
    
    .admin-nav { background: #e74c3c; color: white; padding: 1rem; display: flex; justify-content: space-between; align-items: center; }
    .nav-links { display: flex; gap: 2rem; }
    .nav-links a { color: white; text-decoration: none; padding: 0.5rem 1rem; border-radius: 4px; transition: background 0.3s; }
    .nav-links a:hover { background: rgba(255,255,255,0.2); }
    
    .admin-content { max-width: 1200px; margin: 0 auto; padding: 2rem; }
    .admin-section { display: none; }
    .admin-section.active { display: block; }
    
    .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-top: 1.5rem; }
    .metric-card { background: white; padding: 1.5rem; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .metric-card h3 { color: #666; margin-bottom: 0.5rem; }
    .metric-value { font-size: 2rem; font-weight: bold; color: #e74c3c; }
    
    .refresh-btn { background: #3498db; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 4px; cursor: pointer; margin-bottom: 1.5rem; }
    .refresh-btn:hover { background: #2980b9; }
    
    .demo-orders { display: grid; gap: 1rem; margin-top: 1.5rem; }
    .order-card { background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .order-card h4 { color: #2c3e50; margin-bottom: 0.5rem; }

  app.js: |
    let currentUser = null;
    
    // Initialize admin portal
    document.addEventListener('DOMContentLoaded', function() {
        checkAuthStatus();
        loadDashboardData();
    });
    
    function showSection(sectionName) {
        document.querySelectorAll('.admin-section').forEach(section => {
            section.classList.remove('active');
        });
        document.getElementById(sectionName).classList.add('active');
    }
    
    async function checkAuthStatus() {
        // In a real application, check if user is admin
        console.log('Admin authentication check would happen here');
    }
    
    async function loadDashboardData() {
        try {
            const response = await fetch('/api/catalog/products');
            const data = await response.json();
            document.getElementById('total-products').textContent = data.products ? data.products.length : '0';
        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        }
    }
    
    async function loadProducts() {
        try {
            const response = await fetch('/api/catalog/products');
            const data = await response.json();
            
            const container = document.getElementById('admin-products-list');
            container.innerHTML = '';
            
            data.products.forEach(product => {
                const productDiv = document.createElement('div');
                productDiv.style.cssText = 'background: white; padding: 1rem; margin-bottom: 1rem; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);';
                productDiv.innerHTML = `
                    <h4>${product.title}</h4>
                    <p><strong>Author:</strong> ${product.author}</p>
                    <p><strong>Price:</strong> ${product.price}</p>
                    <p><strong>Category:</strong> ${product.category}</p>
                    <p><strong>Stock:</strong> ${product.stock}</p>
                    <p><strong>Featured:</strong> ${product.featured ? 'Yes' : 'No'}</p>
                `;
                container.appendChild(productDiv);
            });
        } catch (error) {
            console.error('Failed to load products:', error);
        }
    }
    
    async function loadUserProfile() {
        try {
            const response = await fetch('/api/user/health');
            const data = await response.json();
            
            const container = document.getElementById('user-info');
            container.innerHTML = `
                <div style="background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <h3>Service Status</h3>
                    <p><strong>User Service:</strong> ${data.status || 'Unknown'}</p>
                    <p><em>In a real application, this would show user management functionality.</em></p>
                </div>
            `;
        } catch (error) {
            console.error('Failed to load user info:', error);
        }
    }
```

### Deploy Admin Portal and Update Ingress

```bash
kubectl apply -f admin-portal-config.yaml

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-portal
  labels:
    app: techbooks
    component: admin-portal
spec:
  replicas: 2
  selector:
    matchLabels:
      app: techbooks
      component: admin-portal
  template:
    metadata:
      labels:
        app: techbooks
        component: admin-portal
    spec:
      containers:
      - name: admin-portal
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: admin-portal-config
---
apiVersion: v1
kind: Service
metadata:
  name: admin-portal-service
spec:
  selector:
    app: techbooks
    component: admin-portal
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Update Ingress for Admin Portal

```yaml
# Add to techbooks-ingress.yaml under rules:
  - host: admin.techbooks.com
    http:
      paths:
      # Admin API endpoints (same as main site)
      - path: /api/user(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/catalog(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 3002
      # Admin interface
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-portal-service
            port:
              number: 80

  # Vendor portal (similar structure)
  - host: vendors.techbooks.com
    http:
      paths:
      - path: /api/catalog(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 3002
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-portal-service  # Reusing for demo
            port:
              number: 80
```

## Phase 5: Advanced Routing Patterns

### A/B Testing with Ingress

Let's implement A/B testing using Ingress annotations:

```yaml
# ab-testing-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: techbooks-ab-testing
  annotations:
    # Canary deployment - send 10% of traffic to new version
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
    
    # Alternative: Header-based routing for beta users
    nginx.ingress.kubernetes.io/canary-by-header: "X-Beta-User"
    nginx.ingress.kubernetes.io/canary-by-header-value: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: www.techbooks.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: storefront-v2-service  # New version
            port:
              number: 80
```

### Set Up Local DNS and Test

```bash
# Get minikube IP
MINIKUBE_IP=$(minikube ip)

# Add entries to hosts file
echo "$MINIKUBE_IP www.techbooks.com" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP m.techbooks.com" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP admin.techbooks.com" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP vendors.techbooks.com" | sudo tee -a /etc/hosts
```

### Deploy and Test the Complete System

```bash
# Apply the main ingress configuration
kubectl apply -f techbooks-ingress.yaml

# Check all services are running
kubectl get pods -l app=techbooks
kubectl get services -l app=techbooks
kubectl get ingress

# Test each endpoint
curl -k https://www.techbooks.com/health || curl http://www.techbooks.com/
curl -k https://www.techbooks.com/api/catalog/products || curl http://www.techbooks.com/api/catalog/products
curl -k https://admin.techbooks.com/ || curl http://admin.techbooks.com/
```

## Phase 6: Testing and Validation

### Comprehensive Testing Strategy

```bash
#!/bin/bash
# test-ecommerce-platform.sh

echo "🧪 Testing TechBooks E-commerce Platform"

# Test main storefront
echo "Testing main storefront..."
curl -s -o /dev/null -w "Storefront: %{http_code} - %{time_total}s\n" http://www.techbooks.com/

# Test API endpoints
echo "Testing catalog API..."
curl -s -o /dev/null -w "Catalog API: %{http_code} - %{time_total}s\n" http://www.techbooks.com/api/catalog/products

echo "Testing user API..."
curl -s -o /dev/null -w "User API: %{http_code} - %{time_total}s\n" http://www.techbooks.com/api/user/health

echo "Testing cart API..."
curl -s -o /dev/null -w "Cart API: %{http_code} - %{time_total}s\n" http://www.techbooks.com/api/cart/

# Test admin portal
echo "Testing admin portal..."
curl -s -o /dev/null -w "Admin Portal: %{http_code} - %{time_total}s\n" http://admin.techbooks.com/

# Test mobile endpoint
echo "Testing mobile API..."
curl -s -o /dev/null -w "Mobile API: %{http_code} - %{time_total}s\n" http://m.techbooks.com/api/catalog/products

echo "✅ Testing complete!"
```

### Load Testing

```bash
# Simple load test with curl
echo "🚀 Load testing the platform..."

# Test concurrent requests
for i in {1..50}; do
  curl -s http://www.techbooks.com/api/catalog/products > /dev/null &
done

# Monitor response times
time curl -s http://www.techbooks.com/api/catalog/products > /dev/null

echo "Load test complete. Check kubectl top pods for resource usage."
```

### Browser Testing Checklist

**Main Storefront (http://www.techbooks.com)**:
1. ✅ Page loads without errors
2. ✅ Login functionality works
3. ✅ Product search and filtering
4. ✅ Add to cart functionality
5. ✅ Cart persistence across page reloads
6. ✅ Security headers present (check dev tools)

**Admin Portal (http://admin.techbooks.com)**:
1. ✅ Dashboard loads
2. ✅ Product management works
3. ✅ API calls succeed
4. ✅ Navigation between sections

## Phase 7: Troubleshooting Common Issues

### Issue: Session Persistence Problems

**Symptoms**: Cart contents disappear between requests

**Solution**: Check session affinity configuration:
```bash
kubectl describe service cart-service
kubectl get ingress techbooks-ingress -o yaml | grep -i session
```

### Issue: CORS Errors

**Symptoms**: Browser console shows CORS errors for API calls

**Debugging**:
```bash
# Test CORS headers
curl -X OPTIONS http://www.techbooks.com/api/catalog/products \
  -H "Origin: http://www.techbooks.com" \
  -H "Access-Control-Request-Method: GET" \
  -v
```

**Solution**: Verify CORS annotations in Ingress configuration.

### Issue: High Response Times

**Symptoms**: Slow API responses under load

**Investigation**:
```bash
# Check pod resource usage
kubectl top pods -l app=techbooks

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100

# Test individual service performance
kubectl port-forward svc/catalog-service 8080:3002
time curl http://localhost:8080/products
```

## Phase 8: Performance Optimization

### Performance Optimization Ingress

```yaml
# Add these annotations to techbooks-ingress.yaml
metadata:
  annotations:
    # Connection settings
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "5"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-body-size: "8m"
    
    # Buffer settings
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
    
    # Compression
    nginx.ingress.kubernetes.io/enable-brotli: "true"
    
    # HTTP/2
    nginx.ingress.kubernetes.io/use-http2: "true"
    
    # Keep-alive
    nginx.ingress.kubernetes.io/upstream-keepalive-connections: "32"
    nginx.ingress.kubernetes.io/upstream-keepalive-requests: "100"
    nginx.ingress.kubernetes.io/upstream-keepalive-timeout: "60"
    
    # Custom Nginx configuration for advanced caching
    nginx.ingress.kubernetes.io/server-snippet: |
      # API responses caching
      location /api/catalog/products {
        proxy_cache_valid 200 5m;
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        add_header X-Cache-Status $upstream_cache_status;
      }
      
      # Static assets long-term caching
      location ~* \.(jpg|jpeg|png|gif|ico|svg|css|js|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
      }
```

## Phase 9: Production Readiness Checklist

### Security Checklist
- [x] HTTPS enabled with valid certificates
- [x] Security headers configured
- [x] Rate limiting implemented
- [x] CORS properly configured
- [ ] Authentication and authorization (basic implementation)
- [ ] Input validation and sanitization
- [ ] SQL injection prevention
- [ ] XSS protection

### Performance Checklist
- [x] Static asset caching
- [x] API response caching
- [x] HTTP/2 enabled
- [x] Compression enabled
- [ ] CDN integration
- [ ] Database query optimization
- [ ] Image optimization

### Reliability Checklist
- [x] Multiple replicas for each service
- [x] Health checks configured
- [x] Session affinity for stateful services
- [ ] Graceful shutdown handling
- [ ] Circuit breaker pattern
- [ ] Retry mechanisms
- [ ] Monitoring and alerting

## Extension Challenges

### Challenge 1: Implement Real Authentication
Replace the mock authentication with a proper JWT-based system with refresh tokens.

### Challenge 2: Add Payment Processing
Integrate with a payment processor like Stripe (use test mode).

### Challenge 3: Implement Real-time Features
Add real-time inventory updates and notifications using WebSockets.

### Challenge 4: Add Search Functionality
Implement full-text search with Elasticsearch integration.

### Challenge 5: Multi-tenant Architecture
Modify the system to support multiple bookstore brands on the same platform.

## Project Summary

You've successfully built a production-grade e-commerce platform that demonstrates:

✅ **Complex routing architectures** - Multiple services with different routing needs  
✅ **Authentication-aware routing** - JWT-based user sessions  
✅ **Session affinity** - Stateful cart service with sticky sessions  
✅ **Performance optimization** - Caching, compression, rate limiting  
✅ **Multi-domain architecture** - Customer, admin, and vendor portals  
✅ **Security best practices** - Headers, CORS, rate limiting  
✅ **Real-world application patterns** - E-commerce with complex business logic

## Self-Assessment Questions

Before completing the course, ensure you understand:

1. **How do you handle session affinity for stateful services in a load-balanced environment?**
2. **What strategies would you use to implement A/B testing through Ingress routing?**
3. **How do you optimize Ingress configuration for high-performance scenarios?**
4. **What are the key considerations when designing routing for a multi-tenant application?**
5. **How would you implement API versioning and backward compatibility?**
6. **What monitoring and observability patterns are most important for complex routing architectures?**

## Clean-Up

```bash
# Remove DNS entries
sudo sed -i '/techbooks.com/d' /etc/hosts

# Delete all resources
kubectl delete ingress techbooks-ingress
kubectl delete svc -l app=techbooks
kubectl delete deployment -l app=techbooks
kubectl delete configmap -l app=techbooks  # if you labeled them

# Or delete by name
kubectl delete configmap storefront-config admin-portal-config user-service-config catalog-service-config cart-service-config
```

---

# Course Summary and Next Steps

## What You've Accomplished

Congratulations! You've completed a comprehensive journey through Kubernetes Ingress, from basic concepts to production-grade applications. Here's what you've mastered:

### Core Skills Developed
- **Ingress Fundamentals** - Understanding L7 routing vs L4 load balancing
- **Environment Management** - Setting up reliable local Kubernetes clusters
- **Multi-Service Architecture** - Designing and implementing complex routing patterns
- **Security Implementation** - HTTPS, authentication, rate limiting, and security headers
- **Performance Optimization** - Caching strategies, compression, and load balancing
- **Production Patterns** - Session affinity, A/B testing, and monitoring

### Real-World Applications Built
1. **Personal Portfolio** - Multi-service website with API integration
2. **E-commerce Platform** - Complex business application with multiple user types
3. **Admin Portals** - Management interfaces with different access patterns
4. **Mobile APIs** - Optimized endpoints for different client types

### Advanced Patterns Mastered
- **Complex Routing** - Host-based, path-based, and header-based routing
- **Authentication Flows** - JWT tokens, user sessions, and role-based access
- **Session Management** - Sticky sessions for stateful services
- **Performance Tuning** - Caching, compression, and connection optimization
- **Security Hardening** - Production-ready security configurations

## Key Achievements

**🎯 Technical Mastery**: You can design and implement enterprise-grade Ingress solutions that handle real-world complexity.

**🚀 Production Ready**: Your configurations include security, performance, and reliability patterns used in production systems.

**🔧 Troubleshooting Skills**: You know how to debug common issues and optimize performance.

**📈 Scalable Thinking**: You understand how to design routing that can grow with business needs.

## Next Steps in Your Journey

### Immediate Applications
1. **Apply to Personal Projects** - Use these patterns in your own applications
2. **Contribute to Open Source** - Share your knowledge with the community  
3. **Document Your Learning** - Create blog posts or talks about your experience

### Advanced Topics to Explore
1. **Service Mesh** - Istio, Linkerd for more advanced traffic management
2. **GitOps** - Automated deployment pipelines with ArgoCD or Flux
3. **Observability** - Prometheus, Grafana, Jaeger for monitoring and tracing
4. **Multi-Cluster** - Cross-cluster communication and failover
5. **Cloud Provider Specifics** - AWS ALB, GCP Load Balancer, Azure Application Gateway

### Career Development
- **Kubernetes Certifications** - CKA, CKAD, CKS
- **Cloud Certifications** - AWS, GCP, Azure platform-specific knowledge
- **DevOps Practices** - CI/CD, Infrastructure as Code, Monitoring
- **Architecture Patterns** - Microservices, Event-Driven Architecture, Domain-Driven Design

## Community and Continued Learning

### Stay Connected
- **Kubernetes Community** - Join SIGs (Special Interest Groups)
- **Local Meetups** - Share experiences with local practitioners
- **Online Communities** - Reddit r/kubernetes, Discord servers, Stack Overflow
- **Conference Talks** - KubeCon, local DevOps conferences

### Keep Practicing
- **Build More Projects** - Each application teaches new patterns
- **Contribute to Documentation** - Help others learn what you've learned
- **Mentor Others** - Teaching reinforces your own understanding

## Final Thoughts

You've built something significant - not just technical skills, but the confidence to tackle complex infrastructure challenges. The patterns you've learned here are the foundation for scalable, maintainable systems that serve real users.

Remember: **Great engineers aren't those who know everything, but those who know how to learn, adapt, and solve problems systematically.** You've demonstrated all of these qualities.

**The journey doesn't end here - it evolves.** Take these skills, apply them boldly, and continue building amazing things.

---

*Thank you for taking this journey through Kubernetes Ingress. May your deployments be stable, your routing be elegant, and your services be always available! 🚀*