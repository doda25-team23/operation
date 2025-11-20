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

### 1. Navigate to operation directory
```bash
cd operation
```

### 2. Start all services
```bash
docker-compose up -d
```

This will:
- Build Docker images for both services
- Download the SMS dataset
- Train the ML model
- Start both services

**Note**: First startup takes 5-10 minutes for model training.

### 3. Access the application
- **Web UI**: http://localhost:8080/sms
- **API Documentation**: http://localhost:8081/apidocs

### 4. Stop the application
```bash
docker-compose down
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_HOST` | `http://model-service:8081` | Backend API URL |

### Port Configuration

| Service | Port | Description |
|---------|------|-------------|
| Frontend | 8080 | Web UI |
| Model Service | 8081 | ML API |

To change ports, edit `docker-compose.yml`:
```yaml
services:
  frontend:
    ports:
      - "9090:8080"  # External:Internal
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

## Key Files for Understanding the Codebase

### Configuration Files
- [`docker-compose.yml`](docker-compose.yml) - Service orchestration and networking
- [`../app/pom.xml`](../app/pom.xml) - Frontend dependencies
- [`../model-service/requirements.txt`](../model-service/requirements.txt) - Backend dependencies

### Frontend
- [`../app/src/main/java/frontend/ctrl/FrontendController.java`](../app/src/main/java/frontend/ctrl/FrontendController.java) - Main controller handling SMS classification
- [`../app/src/main/resources/templates/sms/index.html`](../app/src/main/resources/templates/sms/index.html) - Web UI

### Backend
- [`../model-service/src/serve_model.py`](../model-service/src/serve_model.py) - Flask API serving predictions
- [`../model-service/src/text_classification.py`](../model-service/src/text_classification.py) - Model training logic
- [`../model-service/src/text_preprocessing.py`](../model-service/src/text_preprocessing.py) - Text preprocessing pipeline

### Deployment
- [`../app/Dockerfile`](../app/Dockerfile) - Frontend container image
- [`../model-service/Dockerfile`](../model-service/Dockerfile) - Backend container image

## Future Additions

This repository will contain:
- Vagrant provisioning scripts
- Ansible playbooks
- Kubernetes manifests
- Monitoring configurations
- CI/CD pipelines
