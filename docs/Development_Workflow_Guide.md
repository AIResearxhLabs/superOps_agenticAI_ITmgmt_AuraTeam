# 🚀 Development Workflow Guide

This guide explains the different development modes available and when to use each one.

---

## 📋 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Development Mode (Hot-Reload)](#development-mode-hot-reload)
3. [Production Mode (Local Testing)](#production-mode-local-testing)
4. [Cloud Deployment](#cloud-deployment)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)

---

## Quick Reference

| Mode | Command | Use Case | Rebuild Required | Speed |
|------|---------|----------|------------------|-------|
| **Dev (Hot-Reload)** | `./deploy-local.sh dev` | Active coding | ❌ No | ⚡ Instant |
| **Production (Local)** | `./deploy-local.sh deploy` | Final testing | ✅ Yes | 🐢 3-5 min |
| **Cloud Deployment** | `./deploy/scripts/deploy-aws-with-alb.sh` | AWS/Cloud | ✅ Yes | 🐢 5-10 min |

---

## Development Mode (Hot-Reload)

### 🎯 Purpose
Fast iteration during active development. See your changes instantly without rebuilding containers.

### ✨ Features
- **Instant Hot-Reload**: Changes appear in 1-2 seconds
- **Volume Mounting**: Source files are mounted into containers
- **React Dev Server**: Full development server with error overlay
- **Backend Hot-Reload**: Python code changes auto-reload too

### 🚀 How to Start

#### Option 1: Using Helper Script (Recommended)
```bash
# Start in development mode
./deploy-local.sh dev

# Stop services
./deploy-local.sh stop

# View logs
./deploy-local.sh logs
```

#### Option 2: Direct Docker Compose
```bash
# Start all services
docker compose -f deploy/environments/local/docker-compose.dev.yml up -d

# View logs
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f frontend

# Stop all services
docker compose -f deploy/environments/local/docker-compose.dev.yml down
```

### 📝 Development Workflow

1. **Start services:**
   ```bash
   ./deploy-local.sh dev
   ```

2. **Open browser:**
   - Frontend: http://localhost:3000
   - API Gateway: http://localhost:8000
   - Service Desk: http://localhost:8001

3. **Edit code:**
   ```bash
   # Edit any file in aura-frontend/src/
   vi aura-frontend/src/pages/ServiceDesk/CreateTicket.js
   
   # Save file
   # Browser automatically refreshes! ✨
   ```

4. **See changes instantly:**
   - React detects file changes
   - Hot-reloads the component
   - Browser updates (1-2 seconds)

5. **Backend changes:**
   ```bash
   # Edit Python files
   vi aura-backend/service-desk-host/main.py
   
   # Uvicorn auto-reloads! ✨
   ```

### ⚙️ Configuration Details

**Frontend Container:**
- **Image**: `node:20-alpine` (development image)
- **Command**: `npm start` (React dev server)
- **Volumes**: 
  - `aura-frontend/src` → `/app/src` (live sync)
  - `aura-frontend/public` → `/app/public` (live sync)
- **Port**: 3000 (direct access)
- **Hot-Reload**: ✅ Enabled

**Backend Containers:**
- **Volumes**: Source code mounted
- **Auto-reload**: Uvicorn watches for changes
- **Debug**: Enabled

### 💡 Tips for Development Mode

✅ **DO:**
- Use for all active development
- Edit files in your local editor
- Commit frequently
- Use browser DevTools for debugging

❌ **DON'T:**
- Use for final testing (use production mode)
- Assume dev build == production build
- Deploy dev config to cloud

### 🔧 Environment Variables

Development mode uses these environment variables:
```bash
# Frontend
REACT_APP_API_URL=http://localhost:8000
REACT_APP_ENVIRONMENT=local
CHOKIDAR_USEPOLLING=true        # Enable file watching in Docker
WATCHPACK_POLLING=true           # Webpack polling
FAST_REFRESH=true                # React Fast Refresh

# Backend
DEBUG=true
ENVIRONMENT=local
CORS_ORIGINS=http://localhost:3000
```

---

## Production Mode (Local Testing)

### 🎯 Purpose
Test the actual production build locally before deploying to cloud.

### ✨ Features
- **Production Build**: Same as cloud deployment
- **Nginx Server**: Static file serving (like production)
- **Optimized**: Minified, tree-shaken code
- **No Hot-Reload**: Requires rebuild for changes

### 🚀 How to Start

#### Option 1: Using Helper Script (Recommended)
```bash
# Deploy in production mode
./deploy-local.sh deploy

# Or just restart (keeps data)
./deploy-local.sh restart

# Full cleanup and restart
./deploy-local.sh deploy --clean
```

#### Option 2: Direct Docker Compose
```bash
# Build and start
docker compose -f deploy/environments/local/docker-compose.yml up -d --build

# Rebuild only frontend
docker compose -f deploy/environments/local/docker-compose.yml up -d --build frontend

# Stop all services
docker compose -f deploy/environments/local/docker-compose.yml down
```

### 📝 Testing Workflow

1. **Make your changes in dev mode**
2. **Switch to production mode:**
   ```bash
   # Stop dev mode
   ./deploy-local.sh stop
   
   # Start production mode
   ./deploy-local.sh deploy
   ```

3. **Test the production build:**
   - Verify UI/UX matches expectations
   - Test all features work
   - Check browser console for errors
   - Verify API integrations

4. **If issues found:**
   ```bash
   # Go back to dev mode
   ./deploy-local.sh stop
   ./deploy-local.sh dev
   
   # Fix issues with hot-reload
   # Repeat testing
   ```

### ⚙️ Configuration Details

**Frontend Container:**
- **Build**: Multi-stage Dockerfile
  1. Stage 1: `npm run build` (creates optimized bundle)
  2. Stage 2: Nginx serves static files
- **Image**: Custom nginx image
- **Port**: 80 → 3000 (mapped)
- **Hot-Reload**: ❌ Disabled

### 🔍 When to Use Production Mode

✅ **Use production mode for:**
- Final testing before cloud deployment
- Verifying production build works
- Testing nginx configuration
- Performance testing
- Build error detection

❌ **Don't use production mode for:**
- Active development (too slow)
- Rapid prototyping
- Debugging (harder without source maps)

---

## Cloud Deployment

### 🎯 Purpose
Deploy the application to AWS ECS (or other cloud providers).

### 🚀 How to Deploy

#### AWS Deployment

```bash
# Full deployment to AWS
./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --force

# Deploy only frontend
./deploy/scripts/deploy-frontend.sh

# Deploy only backend
./deploy/scripts/deploy-backend-aws.sh
```

### 📝 Deployment Workflow

1. **Test locally in production mode:**
   ```bash
   ./deploy-local.sh deploy
   # Test everything works
   ```

2. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: improved create ticket UI with AI visibility"
   git push origin main
   ```

3. **Deploy to cloud:**
   ```bash
   # Ensure AWS CLI is configured
   aws sts get-caller-identity
   
   # Deploy
   ./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --force
   ```

4. **Verify deployment:**
   - Check ECS console
   - Test the live URL
   - Monitor logs in CloudWatch

### ⚙️ What Happens During Cloud Deployment

1. **Build Images**:
   - Uses production Dockerfile (same as local prod mode)
   - Creates optimized builds

2. **Push to Registry**:
   - Tags images with commit SHA
   - Pushes to AWS ECR

3. **Update ECS**:
   - Updates task definitions
   - Performs rolling deployment
   - Health checks ensure smooth transition

4. **Load Balancer**:
   - Routes traffic to new containers
   - Drains old containers gracefully

### 🔒 Security Notes

- ✅ Uses production Dockerfile (no source code exposed)
- ✅ Environment variables from AWS Secrets Manager
- ✅ No volume mounts (immutable containers)
- ✅ HTTPS enforced via ALB
- ✅ IAM roles for service authentication

---

## Troubleshooting

### Hot-Reload Not Working

**Problem**: Changes not appearing after saving file

**Solutions**:
```bash
# 1. Check if dev mode is running
docker compose -f deploy/environments/local/docker-compose.dev.yml ps

# 2. Check frontend logs
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f frontend

# 3. Restart frontend container
docker compose -f deploy/environments/local/docker-compose.dev.yml restart frontend

# 4. Hard refresh browser
# Mac: Cmd + Shift + R
# Windows/Linux: Ctrl + Shift + R

# 5. Clear browser cache and restart
docker compose -f deploy/environments/local/docker-compose.dev.yml down
docker compose -f deploy/environments/local/docker-compose.dev.yml up -d
```

### Port Already in Use

**Problem**: `Port 3000 is already allocated`

**Solutions**:
```bash
# Find what's using the port
lsof -ti:3000

# Kill the process
kill -9 $(lsof -ti:3000)

# Or stop all Docker containers
docker compose -f deploy/environments/local/docker-compose.dev.yml down
docker compose -f deploy/environments/local/docker-compose.yml down
```

### Changes Not Reflected in Production Mode

**Problem**: Changed code but production mode shows old version

**Solution**:
```bash
# Production mode requires rebuild!
docker compose -f deploy/environments/local/docker-compose.yml up -d --build frontend

# Or use helper script
./deploy-local.sh deploy
```

### npm install Errors in Dev Mode

**Problem**: `Cannot find module 'xyz'` after adding new package

**Solution**:
```bash
# Rebuild frontend container to install new packages
docker compose -f deploy/environments/local/docker-compose.dev.yml down frontend
docker compose -f deploy/environments/local/docker-compose.dev.yml build --no-cache frontend
docker compose -f deploy/environments/local/docker-compose.dev.yml up -d frontend
```

### Backend API Not Responding

**Problem**: Frontend loads but API calls fail

**Solutions**:
```bash
# 1. Check if backend is running
docker compose -f deploy/environments/local/docker-compose.dev.yml ps

# 2. Check backend logs
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f api-gateway
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f service-desk-host

# 3. Check health endpoints
curl http://localhost:8000/health
curl http://localhost:8001/health

# 4. Restart backend services
docker compose -f deploy/environments/local/docker-compose.dev.yml restart api-gateway service-desk-host
```

---

## Best Practices

### 🎯 Development Workflow

1. **Start in dev mode** for active coding
2. **Test in production mode** before committing
3. **Commit and push** when tests pass
4. **Deploy to cloud** for staging/production

### 📁 File Organization

```
aura-frontend/
├── src/
│   ├── pages/           # Edit freely with hot-reload
│   ├── components/      # Hot-reload enabled
│   ├── services/        # Hot-reload enabled
│   └── theme/           # Hot-reload enabled
├── public/              # Hot-reload for static files
└── package.json         # Rebuild needed after changes
```

### 🔄 When to Use Each Mode

| Task | Recommended Mode |
|------|-----------------|
| Adding new feature | 🔥 Dev (hot-reload) |
| Fixing bugs | 🔥 Dev (hot-reload) |
| UI/UX improvements | 🔥 Dev (hot-reload) |
| Final testing | 🏗️ Production (local) |
| Pre-deployment check | 🏗️ Production (local) |
| Team demo | 🏗️ Production (local) |
| Staging environment | ☁️ Cloud deployment |
| Production release | ☁️ Cloud deployment |

### ⚡ Performance Tips

**For Development Mode:**
- Close unused containers to save resources
- Use `docker system prune` regularly
- Monitor Docker Desktop resource usage
- Restart containers if memory issues occur

**For Production Testing:**
- Build with `--no-cache` if seeing stale assets
- Clear browser cache between builds
- Test on multiple browsers
- Use Chrome DevTools Network tab for debugging

### 🔐 Security Checklist

Before cloud deployment:
- [ ] Remove debug logging
- [ ] Check for hardcoded secrets
- [ ] Verify environment variables
- [ ] Test authentication flows
- [ ] Review CORS settings
- [ ] Check API rate limiting
- [ ] Verify error handling doesn't expose internals

---

## Quick Commands Cheatsheet

```bash
# ========== DEVELOPMENT MODE ==========
# Start dev mode with hot-reload
./deploy-local.sh dev

# View logs (follow mode)
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f

# Restart specific service
docker compose -f deploy/environments/local/docker-compose.dev.yml restart frontend

# Stop dev mode
./deploy-local.sh stop


# ========== PRODUCTION MODE ==========
# Start production mode
./deploy-local.sh deploy

# Rebuild only frontend
docker compose -f deploy/environments/local/docker-compose.yml up -d --build frontend

# Stop production mode
docker compose -f deploy/environments/local/docker-compose.yml down


# ========== CLOUD DEPLOYMENT ==========
# Deploy to AWS
./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --force

# Check deployment status
aws ecs list-tasks --cluster aura-dev-cluster


# ========== MAINTENANCE ==========
# Clean up Docker
docker system prune -a --volumes

# Reset everything
./deploy-local.sh stop
docker system prune -af --volumes
./deploy-local.sh dev


# ========== DEBUGGING ==========
# Access container shell
docker exec -it <container-name> sh

# Check container logs
docker logs <container-name> --tail 100 -f

# Inspect container
docker inspect <container-name>
```

---

## Summary

- 🔥 **Use Dev Mode** for 99% of development work (instant feedback)
- 🏗️ **Use Production Mode** for final testing before deployment
- ☁️ **Use Cloud Deployment** for staging and production releases
- 📚 **Keep this guide handy** and share with the team!

---

**Questions or Issues?**
- Check the [Troubleshooting](#troubleshooting) section
- Review Docker logs for errors
- Ask the team in Slack/Teams
- Update this guide if you find solutions to new issues!
