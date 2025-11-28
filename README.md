# SMS Spam Detection System - Operations

This repository contains all operational configurations for deploying and running the SMS Spam Detection System.

## Overview

The SMS Spam Detection System is a microservices application that classifies SMS messages as spam or legitimate (ham). It consists of two services:

1. **Frontend Service**: Web UI (Spring Boot/Java) - Port 8080
2. **Model Service**: ML inference API (Flask/Python) - Port 8081

## Requirements

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **System**: 4GB RAM minimum, 5GB disk space

Verify installation:

```bash
docker --version
docker-compose --version
```

## How to Start the Application

### Option 1: Using Pre-built Images (Recommended)

```bash
cd operation
docker-compose pull  # Pull latest images from GitHub Container Registry
docker-compose up -d
```

### Option 2: Building Locally

```bash
cd operation
docker-compose up -d --build
```

This will:

- Build Docker images for both services (or pull from registry if available)
- Download the SMS dataset
- Train the ML model
- Start both services

**Note**: Local builds take 5-10 minutes for model training.

### 3. Access the application

- **Web UI**: http://localhost:8080/sms
- **API Documentation**: http://localhost:8081/apidocs

### 4. Stop the application

```bash
docker-compose down
```

## Configuration

### Environment Variables

| Variable     | Default                     | Description     |
| ------------ | --------------------------- | --------------- |
| `MODEL_HOST` | `http://model-service:8081` | Backend API URL |

### Port Configuration

| Service       | Port | Description |
| ------------- | ---- | ----------- |
| Frontend      | 8080 | Web UI      |
| Model Service | 8081 | ML API      |

To change ports, edit `docker-compose.yml`:

```yaml
services:
  frontend:
    ports:
      - "9090:8080" # External:Internal
```

## Project Structure

```
operation/
├── docker-compose.yml       # Service orchestration
└── README.md               # This file

../app/                     # Frontend service
├── src/                    # Java source code
│   └── main/java/frontend/ctrl/
│       ├── FrontendController.java
│       └── HelloWorldController.java
├── pom.xml                 # Maven configuration
└── Dockerfile              # Container definition

../model-service/           # Backend ML service
├── src/                    # Python source code
│   ├── get_data.py         # Dataset download
│   ├── text_preprocessing.py
│   ├── text_classification.py
│   └── serve_model.py      # API server
├── requirements.txt        # Dependencies
└── Dockerfile              # Container definition

../lib-version/             # Version library
└── src/main/java/doda25/team23/VersionUtil.java
```

## Key Repositories for Understanding the Codebase

### Frontend Service

- **Repository**: https://github.com/doda25-team23/app
- **Technology**: Java 25, Spring Boot 3.5.7
- **Key components**: Controllers, Thymeleaf templates, REST client

### Backend Service

- **Repository**: https://github.com/doda25-team23/model-service
- **Technology**: Python 3.12, Flask, scikit-learn
- **Key components**: ML pipeline, preprocessing, model training, API server

### Version Library

- **Repository**: https://github.com/doda25-team23/lib-version
- **Technology**: Java, Maven
- **Purpose**: Version awareness utility for applications

### Operations

- **Repository**: https://github.com/doda25-team23/operation
- **Purpose**: Docker Compose, deployment configurations, and operational scripts

## Container Images

Published container images are available on GitHub Container Registry:

- **Frontend**: `ghcr.io/doda25-team23/app:latest`
- **Backend**: `ghcr.io/doda25-team23/model-service:latest`

### Versioning

- **app**: Version automatically extracted from `pom.xml` on every push to main/master
- **model-service**: Version determined by git tags (format: `v1.0.0`)

### Triggering Releases

**Frontend (app)**:

```bash
cd app
git add .
git commit -m "Update application"
git push origin master
# Workflow automatically triggers and builds image with version from pom.xml
```

**Backend (model-service)**:

```bash
cd model-service
git tag v1.0.0
git push origin v1.0.0
# Workflow automatically triggers and builds image with tag version
```

## Kubernetes Lab Environment (Assignment A2)

Follow `K8S_SETUP.md` for the complete workflow (prerequisites, `vagrant up`, Person D’s `finalization.yml`, kubeconfig export, troubleshooting, etc.). Keeping the detailed runbook in that single document avoids duplicate instructions here.

## Future Additions

This repository will contain:

- Vagrant provisioning scripts
- Ansible playbooks
- Kubernetes manifests
- Monitoring configurations
- CI/CD pipelines
