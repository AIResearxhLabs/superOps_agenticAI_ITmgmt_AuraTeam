# Aura Unified Deployment Guide

## Overview

This guide explains the new unified deployment architecture for the Aura IT Management Suite, which consolidates all backend services into a single container to fix frontend-backend connectivity issues.

## What Changed?

### Previous Architecture (Split Services)
```
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐
│   Frontend  │────▶│ API Gateway │────▶│ Service Desk Host│
└─────────────┘     └─────────────┘     └──────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Databases  │
                    └──────────────┘
```

**Issues:**
- Network routing between containers
- CORS configuration complexity
- Service discovery problems in AWS ECS
- Frontend unable to reach backend in some deployments

### New Architecture (Unified Service)
```
┌─────────────┐     ┌────────────────────────────────┐
│   Frontend  │────▶│   Aura Unified Service         │
└─────────────┘     │  ┌──────────────────────────┐  │
                    │  │ API Gateway              │  │
                    │  │ Service Desk Host        │  │
                    │  │ Threat Intelligence      │  │
                    │  └──────────────────────────┘  │
                    └────────────────────────────────┘
                                   │
                                   ▼
                            ┌──────────────┐
                            │   Databases  │
                            └──────────────┘
```

**Benefits:**
- ✅ Single service endpoint
- ✅ No inter-service networking issues
- ✅ Simplified CORS configuration
- ✅ Easier deployment and debugging
- ✅ All logs in one place
- ✅ Reduced resource usage

## Quick Start

### Local Development

1. **Clone the repository**
```bash
git clone <repository-url>
cd superOps_agenticAI_ITmgmt_AuraTeam
```

2. **Set up environment variables**
```bash
cd aura-backend
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
```

3. **Start the unified stack**
```bash
docker-compose -f docker-compose-unified.yml up --build
```

4. **Access the application**
- Frontend: http://localhost:3000
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### AWS Deployment

1. **Configure AWS credentials**
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-2)
```

2. **Set up OpenAI API Key in AWS Systems Manager**
```bash
aws ssm put-parameter \
  --name "/aura/dev/openai-api-key" \
  --value "your-openai-api-key" \
  --type "SecureString" \
  --region us-east-2
```

3. **Deploy using the unified script**
```bash
chmod +x deploy/scripts/deploy-unified.sh
./deploy/scripts/deploy-unified.sh
```

The script will automatically:
- Build and push all Docker images to ECR
- Create/update ECS cluster
- Deploy the unified task definition
- Configure networking and security groups
- Provide access URLs

## File Structure

### New Files Created
```
aura-backend/
├── aura-service/                          # NEW: Unified service directory
│   ├── Dockerfile                         # Multi-stage Docker build
│   ├── main.py                           # Unified FastAPI application
│   ├── start.sh                          # Startup script with health checks
│   └── README.md                         # Detailed service documentation
├── docker-compose-unified.yml            # NEW: Unified deployment config
└── docker-compose-working.yml            # OLD: Split services (kept for reference)

deploy/
├── aws/
│   └── ecs/
│       ├── task-definition-unified.json   # NEW: Unified ECS task definition
│       └── task-definition.json          # OLD: Split services task definition
└── scripts/
    ├── deploy-unified.sh                 # NEW: Unified deployment script
    └── deploy-consolidated.sh            # OLD: Split deployment script

UNIFIED_DEPLOYMENT_GUIDE.md              # NEW: This guide
```

## Configuration

### Environment Variables

The unified service uses the following environment variables:

#### Application Settings
```bash
HOST=0.0.0.0
PORT=8000
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO
```

#### Database Configuration
```bash
DATABASE_URL=postgresql://aura_user:aura_password@localhost:5432/aura_servicedesk
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=aura_user
POSTGRES_PASSWORD=aura_password
```

#### MongoDB Configuration
```bash
MONGODB_URL=mongodb://localhost:27017/aura_servicedesk
MONGO_HOST=localhost
MONGO_PORT=27017
```

#### Redis Configuration
```bash
REDIS_URL=redis://localhost:6379
REDIS_HOST=localhost
REDIS_PORT=6379
```

#### OpenAI API
```bash
OPENAI_API_KEY=your-api-key-here
```

#### Initialization Flags
```bash
INIT_DB=true           # Initialize database schema on startup
POPULATE_DATA=true     # Populate sample data on startup
```

## API Endpoints

All endpoints are now available through a single service at `http://<host>:8000`:

### Health & Info
- `GET /` - Service information
- `GET /health` - Health check with dependency status
- `GET /api/v1/services/status` - Status of all integrated services
- `GET /api/v1/info` - Comprehensive service information

### Service Desk
- `GET /api/v1/tickets` - List all tickets
- `POST /api/v1/tickets` - Create a new ticket
- `GET /api/v1/tickets/{id}` - Get ticket by ID
- `PUT /api/v1/tickets/{id}` - Update ticket
- `POST /api/v1/tickets/{id}/analyze` - AI analysis and routing

### Knowledge Base
- `GET /api/v1/kb/articles` - List articles
- `POST /api/v1/kb/search` - Search articles
- `POST /api/v1/kb/articles` - Create article
- `GET /api/v1/kb/recommendations` - Get recommendations

### Chatbot
- `POST /api/v1/chatbot/message` - Send message to chatbot

### Dashboard
- `GET /api/v1/dashboard/overview` - Dashboard overview
- `GET /api/v1/dashboard/ticket-metrics` - Ticket metrics

### Security (Threat Intelligence)
- `GET /api/v1/security/dashboard` - Security dashboard
- `GET /api/v1/security/incidents` - Security incidents
- `GET /api/v1/security/threat-intel/feeds` - Threat intelligence feeds

## Deployment Commands

### Local Development
```bash
# Start services
docker-compose -f aura-backend/docker-compose-unified.yml up --build

# View logs
docker-compose -f aura-backend/docker-compose-unified.yml logs -f aura-service

# Stop services
docker-compose -f aura-backend/docker-compose-unified.yml down

# Rebuild and restart
docker-compose -f aura-backend/docker-compose-unified.yml up --build --force-recreate
```

### AWS Deployment
```bash
# Deploy using script (recommended)
./deploy/scripts/deploy-unified.sh

# Or manually:
# 1. Build and push images
cd aura-backend
docker build -f aura-service/Dockerfile -t 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-unified-service:latest .
docker push 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-unified-service:latest

# 2. Register task definition
aws ecs register-task-definition \
  --cli-input-json file://deploy/aws/ecs/task-definition-unified.json \
  --region us-east-2

# 3. Update service
aws ecs update-service \
  --cluster aura-cluster \
  --service aura-unified-service \
  --task-definition aura-app-unified \
  --force-new-deployment \
  --region us-east-2
```

## Monitoring & Debugging

### Health Checks
```bash
# Check overall health
curl http://localhost:8000/health

# Check service status
curl http://localhost:8000/api/v1/services/status

# View comprehensive info
curl http://localhost:8000/api/v1/info
```

### Logs

#### Local (Docker Compose)
```bash
# All services
docker-compose -f aura-backend/docker-compose-unified.yml logs -f

# Specific service
docker-compose -f aura-backend/docker-compose-unified.yml logs -f aura-service
docker-compose -f aura-backend/docker-compose-unified.yml logs -f postgres
```

#### AWS (CloudWatch)
```bash
# Tail logs
aws logs tail /ecs/aura-app-unified --follow --region us-east-2

# Get recent logs
aws logs tail /ecs/aura-app-unified --since 5m --region us-east-2

# Filter by container
aws logs tail /ecs/aura-app-unified --follow --filter-pattern "aura-service" --region us-east-2
```

## Troubleshooting

### Issue: Service won't start

**Solution:**
```bash
# Check database connectivity
docker-compose -f aura-backend/docker-compose-unified.yml logs postgres mongo redis

# Verify environment variables
docker-compose -f aura-backend/docker-compose-unified.yml config

# Check service logs
docker-compose -f aura-backend/docker-compose-unified.yml logs aura-service
```

### Issue: Frontend can't connect to backend

**Solution:**
1. Verify API is running:
```bash
curl http://localhost:8000/health
```

2. Check frontend environment configuration in `aura-frontend/src/config/environment.js`

3. For AWS, ensure security groups allow inbound traffic on port 8000

### Issue: Database connection errors

**Solution:**
1. Wait for databases to be ready (check health checks in logs)
2. Verify connection strings in environment variables
3. Check network connectivity between containers

### Issue: Missing OpenAI API key

**Solution:**
1. Add to `.env` file for local development
2. For AWS, ensure parameter exists in Systems Manager:
```bash
aws ssm get-parameter --name "/aura/dev/openai-api-key" --region us-east-2
```

## Migration from Split Services

If you have existing deployments using the old split architecture:

### Local Development
```bash
# 1. Stop old services
docker-compose -f aura-backend/docker-compose-working.yml down

# 2. Start new unified services
docker-compose -f aura-backend/docker-compose-unified.yml up --build

# Data in volumes is preserved
```

### AWS Deployment
```bash
# 1. Deploy new unified service
./deploy/scripts/deploy-unified.sh

# 2. Once verified, stop old services
aws ecs update-service \
  --cluster aura-cluster \
  --service <old-service-name> \
  --desired-count 0 \
  --region us-east-2
```

## Performance Optimization

### Resource Allocation
- **Development**: 1 vCPU, 2GB RAM
- **Production**: 2 vCPU, 4GB RAM
- **High Traffic**: 4 vCPU, 8GB RAM with auto-scaling

### Scaling
```bash
# Update ECS service desired count
aws ecs update-service \
  --cluster aura-cluster \
  --service aura-unified-service \
  --desired-count 3 \
  --region us-east-2
```

## Security Considerations

1. **API Keys**: Always use AWS Systems Manager Parameter Store for secrets
2. **Network**: Configure security groups to allow only necessary traffic
3. **CORS**: Frontend-backend in same task eliminates CORS issues
4. **Authentication**: Implement proper JWT/OAuth authentication (future enhancement)

## Next Steps

1. ✅ **Deployed unified architecture**
2. 🔄 Test frontend-backend connectivity
3. 🔄 Verify all API endpoints
4. 🔄 Monitor performance and logs
5. 📝 Update team documentation
6. 🗑️ Remove old split service configurations (after verification)

## Support & Resources

- **Documentation**: `/docs` directory
- **API Docs**: http://localhost:8000/docs (when running)
- **Service README**: `aura-backend/aura-service/README.md`
- **Deployment Scripts**: `deploy/scripts/`

## Version History

- **v1.0.0** (Current) - Unified service architecture
  - Combined all backend services into single container
  - Fixed frontend-backend connectivity issues
  - Simplified deployment process
  - Improved logging and monitoring

---

**Last Updated**: November 23, 2025
**Status**: ✅ Ready for deployment
