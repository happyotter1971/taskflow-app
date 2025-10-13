# TaskFlow App

A cloud-native task management application built with Flask and designed for Kubernetes/OpenShift deployment.

## Overview

TaskFlow is a RESTful API service for managing tasks. It supports both in-memory storage (development) and PostgreSQL database (production), making it suitable for learning container orchestration and cloud deployment patterns.

## Architecture

- **Backend**: Flask (Python) REST API
- **Container Runtime**: Docker
- **Orchestration**: Kubernetes/OpenShift
- **Database**: PostgreSQL (optional, enabled with `USE_DATABASE=true`)
- **Storage**: In-memory (default) or PostgreSQL

## Project Structure

```
taskflow-app/
├── app/
│   ├── backend/
│   │   ├── app.py              # Flask application
│   │   ├── Dockerfile          # Container image definition
│   │   └── requirements.txt    # Python dependencies
│   └── k8s/
│       └── week1-kubernetes/
│           ├── namespace.yaml   # Kubernetes namespace
│           ├── configmap.yaml   # Application configuration
│           ├── deployment.yaml  # Application deployment
│           └── service.yaml     # Service exposure
└── README.md
```

## API Endpoints

- `GET /` - Application info
- `GET /api` - API information with database status
- `GET /health` - Health check endpoint
- `GET /api/tasks` - List all tasks
- `POST /api/tasks` - Create a new task
- `PUT /api/tasks/<id>` - Update a task
- `DELETE /api/tasks/<id>` - Delete a task

## Local Development

### Prerequisites

- Python 3.13+
- Docker (for containerization)
- Kubernetes/OpenShift cluster (for deployment)

### Run Locally

```bash
cd app/backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

The API will be available at `http://localhost:8080`

### Test the API

```bash
# Get all tasks
curl http://localhost:8080/api/tasks

# Create a task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"New Task"}'

# Update a task
curl -X PUT http://localhost:8080/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'

# Delete a task
curl -X DELETE http://localhost:8080/api/tasks/1
```

## Container Build

```bash
cd app/backend
docker build -t taskflow-backend:v1.0 .
docker run -p 8080:8080 taskflow-backend:v1.0
```

## Kubernetes Deployment

### Deploy to Cluster

```bash
# Apply all manifests
kubectl apply -f app/k8s/week1-kubernetes/

# Check deployment status
kubectl get all -n happyotter-dev

# View logs
kubectl logs -n happyotter-dev deployment/taskflow-backend
```

### Access the Service

```bash
# Port forward to local machine
kubectl port-forward -n happyotter-dev service/taskflow-backend 8080:8080

# Or get the service URL (if using LoadBalancer/NodePort)
kubectl get service -n happyotter-dev taskflow-backend
```

## Configuration

The application uses environment variables configured via ConfigMap:

- `APP_VERSION` - Application version (default: "1.0")
- `ENVIRONMENT` - Environment name (default: "development")
- `USE_DATABASE` - Enable PostgreSQL (default: "false")
- `DB_HOST` - Database host (when USE_DATABASE=true)
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password (use Secrets in production)
- `DB_PORT` - Database port (default: "5432")

## Features

### Week 1 Implementation ✓

- [x] Containerized Flask application
- [x] Kubernetes manifests (Namespace, ConfigMap, Deployment, Service)
- [x] RESTful API with CRUD operations
- [x] Health check endpoint
- [x] Resource limits and requests
- [x] Liveness and readiness probes
- [x] Security context configuration

### Upcoming Features

- PostgreSQL database integration
- Persistent volume claims
- Secrets management
- Frontend application
- CI/CD pipeline
- Monitoring and logging

## Deployment Details

- **Namespace**: `happyotter-dev`
- **Replicas**: 2
- **Image**: `quay.io/happyotter/taskflow-backend:v1.0`
- **Port**: 8080
- **Resource Requests**: 100m CPU, 128Mi memory
- **Resource Limits**: 500m CPU, 512Mi memory

## License

This project is for educational purposes.
