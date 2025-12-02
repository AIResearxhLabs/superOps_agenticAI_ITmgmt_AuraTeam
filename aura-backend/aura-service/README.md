# Aura Unified Service

This directory contains the consolidated Aura service that combines all backend microservices into a single unified application.

## Architecture Overview

The Aura Unified Service consolidates the following components:
- **API Gateway**: Entry point for all API requests
- **Service Desk Host**: Ticket management, knowledge base, and chatbot
- **Threat Intelligence Agent**: Security monitoring and threat feeds

All services run within a single container, simplifying deployment and fixing frontend-backend connectivity issues.

## Structure

```
aura-service/
├── Dockerfile          # Multi-stage Docker build for unified service
├── main.py            # Unified FastAPI application
├── start.sh           # Startup script with health checks
└── README.md          # This file
```

## Features

### Unified API Endpoints
- **Service Desk**: `/api/v1/tickets`, `/api/v1/kb`, `/api/v1/chatbot`, `/api/v1/dashboard`
- **Threat Intelligence**: `/api/v1/security`
- **Health Check**: `/health`
- **Documentation**: `/docs` (Interactive Swagger UI)

### Benefits of Unified Architecture
1. **Simplified Deployment**: Single container to deploy instead of multiple services
2. **No Network Issues**: All services communicate internally without network hops
3. **Reduced Resource Usage**: Shared resources and connections
4. **Easier Debugging**: All logs in one place
5. **Fixed Frontend-Backend Connectivity**: No more CORS or routing issues

## Environment Variables

### Application Settings
- `HOST` - Server host (default: `0.0.0.0`)
- `PORT` - Server port (default: `8000`)
- `ENVIRONMENT` - Environment name (default: `production`)
- `DEBUG` - Enable debug mode (default: `false`)
- `LOG_LEVEL` - Logging level (default: `INFO`)

### Database Configuration
- `DATABASE_URL` - PostgreSQL connection string
- `POSTGRES_HOST` - PostgreSQL host
- `POSTGRES_PORT` - PostgreSQL port (default: `5432`)
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password

### MongoDB Configuration
- `MONGODB_URL` - MongoDB connection string
- `MONGO_HOST` - MongoDB host
- `MONGO_PORT` - MongoDB port (default: `27017`)

### Redis Configuration
- `REDIS_URL` - Redis connection string
- `REDIS_HOST` - Redis host
- `REDIS_PORT` - Redis port (default: `6379`)

### API Keys
- `OPENAI_API_KEY` - OpenAI API key for AI features

### Initialization Flags
- `INIT_DB` - Initialize database schema on startup (default: `false`)
- `POPULATE_DATA` - Populate sample data on startup (default: `false`)

## Local Development

### Using Docker Compose

1. Set up environment variables:
```bash
cd aura-backend
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
```

2. Start all services:
```bash
docker-compose -f docker-compose-unified.yml up --build
```

3. Access the application:
- Frontend: http://localhost:3000
- API: http://localhost:8000
- API Documentation: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### Manual Setup

1. Install dependencies:
```bash
cd aura-backend
pip install -r aura-service/requirements.txt
```

2. Start databases (PostgreSQL, MongoDB, Redis):
```bash
docker-compose -f docker-compose-unified.yml up postgres mongo redis
```

3. Run the unified service:
```bash
cd aura-backend
python aura-service/main.py
```

## AWS Deployment

### Using the Deployment Script

1. Configure AWS credentials:
```bash
aws configure
```

2. Run the unified deployment script:
```bash
./deploy/scripts/deploy-unified.sh
```

The script will:
- Build and push all Docker images to ECR
- Create/update ECS cluster and service
- Deploy the unified task definition
- Provide access URLs

### Manual Deployment

1. Build and push images:
```bash
# Login to ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 753353727891.dkr.ecr.us-east-2.amazonaws.com

# Build and push
cd aura-backend
docker build -f aura-service/Dockerfile -t 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-unified-service:latest .
docker push 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-unified-service:latest
```

2. Register task definition:
```bash
aws ecs register-task-definition --cli-input-json file://deploy/aws/ecs/task-definition-unified.json --region us-east-2
```

3. Create or update service:
```bash
aws ecs update-service --cluster aura-cluster --service aura-unified-service --task-definition aura-app-unified --force-new-deployment --region us-east-2
```

## Health Checks

The unified service provides comprehensive health checks:

```bash
curl http://localhost:8000/health
```

Response includes:
- Overall service status
- PostgreSQL connection status
- MongoDB connection status
- Redis connection status

## Monitoring

### Logs
All services log to the same output stream, making debugging easier:

```bash
# Docker Compose
docker-compose -f docker-compose-unified.yml logs -f aura-service

# AWS CloudWatch
aws logs tail /ecs/aura-app-unified --follow
```

### Metrics
Service metrics are available at:
- `/api/v1/services/status` - Status of all integrated services
- `/api/v1/info` - Comprehensive service information

## Troubleshooting

### Service Won't Start
1. Check database connectivity:
```bash
docker-compose -f docker-compose-unified.yml logs postgres mongo redis
```

2. Verify environment variables are set correctly

3. Check service logs for specific errors:
```bash
docker-compose -f docker-compose-unified.yml logs aura-service
```

### Frontend Can't Connect to Backend
1. Verify the API is running:
```bash
curl http://localhost:8000/health
```

2. Check CORS settings in the frontend configuration

3. For AWS deployments, ensure security groups allow traffic on port 8000

### Database Connection Issues
1. Ensure databases are running and healthy
2. Verify connection strings in environment variables
3. Check network connectivity between containers

## Migration from Split Services

If migrating from the previous split architecture:

1. Stop existing services:
```bash
docker-compose -f docker-compose-working.yml down
```

2. Start unified services:
```bash
docker-compose -f docker-compose-unified.yml up --build
```

3. Data will be preserved if using volume mounts

## Performance Considerations

### Resource Allocation
- Recommended CPU: 1024-2048 units (1-2 vCPUs)
- Recommended Memory: 2048-4096 MB (2-4 GB)

### Scaling
For high-traffic scenarios:
1. Increase task count in ECS
2. Use Application Load Balancer for distribution
3. Configure auto-scaling based on CPU/memory metrics

## Support

For issues or questions:
1. Check logs for error messages
2. Verify all environment variables are set correctly
3. Ensure all dependencies (databases) are healthy
4. Review the deployment documentation in `/docs`

## Version History

- **v1.0.0**: Initial unified service release
  - Combined API Gateway, Service Desk, and Threat Intelligence
  - Fixed frontend-backend connectivity issues
  - Simplified deployment architecture
