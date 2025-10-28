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
│   └── database/
│       └── init.sql            # Database schema initialization
├── k8s/
│   ├── week1-kubernetes/       # Basic Kubernetes deployment
│   ├── week2-s2i/              # Source-to-Image build configs
│   └── week3-database/         # PostgreSQL StatefulSet & integration
│       ├── postgres-statefulset.yaml
│       ├── database-secret.yaml
│       ├── configmap-with-db.yaml
│       └── deployment-with-db.yaml
├── docs/
│   ├── week3-precheck.sh       # Week 3 prerequisites check
│   └── verify-week3.sh         # Week 3 verification script
├── get-db-pod.sh               # Database pod helper script
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

## Deployment

### OpenShift Deployment (Current)

```bash
# Prerequisites check
./docs/week3-precheck.sh

# Deploy PostgreSQL StatefulSet
oc apply -f k8s/week3-database/postgres-statefulset.yaml

# Create database secret
oc apply -f k8s/week3-database/database-secret.yaml

# Update ConfigMap and Deployment with database integration
oc apply -f k8s/week3-database/configmap-with-db.yaml
oc apply -f k8s/week3-database/deployment-with-db.yaml

# Initialize database
DB_POD=$(./get-db-pod.sh happyotter-dev)
oc cp app/database/init.sql $DB_POD:/tmp/init.sql -n happyotter-dev
oc exec -it $DB_POD -n happyotter-dev -- psql -U taskflowuser -d taskflowdb -f /tmp/init.sql

# Verify deployment
./docs/verify-week3.sh
```

### Kubernetes Deployment (Week 1)

```bash
# Apply all manifests
kubectl apply -f k8s/week1-kubernetes/

# Check deployment status
kubectl get all -n happyotter-dev

# View logs
kubectl logs -n happyotter-dev deployment/taskflow-backend
```

### Access the Application

```bash
# OpenShift Route (automatic)
ROUTE=$(oc get route taskflow-backend -n happyotter-dev -o jsonpath='{.spec.host}')
curl https://$ROUTE/health

# Kubernetes Port Forward
kubectl port-forward -n happyotter-dev service/taskflow-backend 8080:8080
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

### Week 1: Kubernetes Basics ✓

- [x] Containerized Flask application
- [x] Kubernetes manifests (Namespace, ConfigMap, Deployment, Service)
- [x] RESTful API with CRUD operations
- [x] Health check endpoint
- [x] Resource limits and requests
- [x] Liveness and readiness probes
- [x] Security context configuration

### Week 2: OpenShift & CI/CD ✓

- [x] OpenShift deployment
- [x] Source-to-Image (S2I) builds
- [x] BuildConfig and ImageStream
- [x] OpenShift Routes for external access
- [x] GitHub webhook integration
- [x] Automated CI/CD pipeline

### Week 3: Database Integration ✓

- [x] PostgreSQL StatefulSet deployment
- [x] Persistent Volume Claims (PVC)
- [x] Database secrets management
- [x] Application-database connectivity
- [x] Database initialization scripts
- [x] Connection pooling
- [x] Health checks with database status

### Upcoming Features

- Ansible automation
- Frontend application
- Monitoring and logging
- Advanced security features

## Deployment Details

### Application
- **Namespace**: `happyotter-dev`
- **Backend Replicas**: 2
- **Image**: `quay.io/happyotter/taskflow-backend` (built via S2I)
- **Port**: 8080
- **Resource Requests**: 100m CPU, 128Mi memory
- **Resource Limits**: 500m CPU, 512Mi memory

### Database
- **Type**: PostgreSQL 15 (Alpine)
- **Deployment**: StatefulSet (1 replica)
- **Storage**: 1Gi Persistent Volume (gp3 storage class)
- **Service**: Headless service (ClusterIP: None)
- **Port**: 5432
- **Resource Requests**: 100m CPU, 256Mi memory
- **Resource Limits**: 500m CPU, 512Mi memory

### URLs
- **API**: https://taskflow-backend-happyotter-dev.apps.rm3.7wse.p1.openshiftapps.com
- **Health**: https://taskflow-backend-happyotter-dev.apps.rm3.7wse.p1.openshiftapps.com/health
- **Tasks API**: https://taskflow-backend-happyotter-dev.apps.rm3.7wse.p1.openshiftapps.com/api/tasks

## License

This project is for educational purposes.
