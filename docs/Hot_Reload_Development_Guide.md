# 🔥 Hot-Reload Development Guide

## Quick Start

```bash
# Start with hot-reload (see changes instantly!)
./deploy-local.sh dev

# Your browser: http://localhost:3000
# Edit files → Save → Changes appear in 1-2 seconds! ✨
```

---

## What is Hot-Reload?

Hot-reload (also called "hot module replacement" or "live reload") automatically updates your application when you save code changes, **without requiring a full rebuild or browser refresh**.

### Traditional Workflow (Production Mode) 🐢
```
Edit Code → Save → Rebuild Container (3-5 min) → Refresh Browser → See Changes
```

### Hot-Reload Workflow (Dev Mode) ⚡
```
Edit Code → Save → Changes Appear Instantly (1-2 sec) ✨
```

---

## Setup Complete! ✅

Your project now has **two deployment modes**:

### 1️⃣ Development Mode (Hot-Reload) - `docker-compose.dev.yml`
**Use for:** Active coding and rapid iteration

```bash
./deploy-local.sh dev
```

**Features:**
- ✅ Frontend hot-reload enabled
- ✅ Backend hot-reload enabled
- ✅ Source files mounted as volumes
- ✅ React dev server with error overlay
- ✅ No rebuild needed for code changes

### 2️⃣ Production Mode (Build & Deploy) - `docker-compose.yml`
**Use for:** Final testing before cloud deployment

```bash
./deploy-local.sh deploy
```

**Features:**
- ✅ Production-optimized build
- ✅ Nginx static file serving
- ✅ Minified and tree-shaken code
- ✅ Same configuration as cloud deployment

---

## Common Commands

### Development Mode Commands

```bash
# Start dev mode
./deploy-local.sh dev

# View live logs
./deploy-local.sh logs

# Check status
./deploy-local.sh status

# Stop services
./deploy-local.sh stop

# Restart services
./deploy-local.sh restart
```

### Making Changes

```bash
# 1. Start dev mode
./deploy-local.sh dev

# 2. Edit any file in aura-frontend/src/
# Example: aura-frontend/src/pages/ServiceDesk/CreateTicket.js

# 3. Save the file
# → Browser automatically refreshes! ✨
# → No rebuild needed!

# 4. Backend changes work too!
# Edit: aura-backend/service-desk-host/main.py
# → FastAPI auto-reloads! ✨
```

---

## How It Works

### Frontend (React)
```yaml
frontend:
  image: node:20-alpine
  command: npm start              # React dev server
  volumes:
    - ./aura-frontend/src:/app/src         # Live mount
    - ./aura-frontend/public:/app/public   # Live mount
  environment:
    - CHOKIDAR_USEPOLLING=true    # File watching
    - FAST_REFRESH=true           # React Fast Refresh
```

**What's Mounted:**
- ✅ `/src` folder (all React components, pages, services)
- ✅ `/public` folder (static assets)
- ✅ `package.json` (for dependency tracking)
- 📦 `node_modules` (persisted in named volume)

### Backend (FastAPI)
```yaml
service-desk-host:
  volumes:
    - ./aura-backend/service-desk-host:/app  # Live mount
    - ./aura-backend/shared:/app/shared      # Live mount
  command: uvicorn main:app --reload  # Auto-reload enabled
```

**What's Mounted:**
- ✅ Service-specific code
- ✅ Shared utilities and models
- 🔄 Uvicorn watches for changes

---

## Troubleshooting

### Changes Not Appearing?

**1. Hard refresh your browser:**
```bash
# Mac: Cmd + Shift + R
# Windows/Linux: Ctrl + Shift + R
```

**2. Check if dev mode is running:**
```bash
./deploy-local.sh status
# Should show "HOT-RELOAD ENABLED"
```

**3. View container logs:**
```bash
docker compose -f deploy/environments/local/docker-compose.dev.yml logs -f frontend
# Should show "webpack compiled successfully"
```

**4. Restart frontend:**
```bash
docker compose -f deploy/environments/local/docker-compose.dev.yml restart frontend
```

### Need to Install New Package?

```bash
# Add package to package.json
# Then rebuild container:
docker compose -f deploy/environments/local/docker-compose.dev.yml down frontend
docker compose -f deploy/environments/local/docker-compose.dev.yml up -d frontend

# npm install will run automatically
```

### Port Already in Use?

```bash
# Stop all services
./deploy-local.sh stop

# Kill any process using port 3000
lsof -ti:3000 | xargs kill -9

# Start again
./deploy-local.sh dev
```

---

## Testing Before Deployment

Always test in production mode before deploying to cloud:

```bash
# 1. Stop dev mode
./deploy-local.sh stop

# 2. Test production build locally
./deploy-local.sh deploy

# 3. Verify everything works at http://localhost:3000

# 4. If good, deploy to cloud
./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --force
```

---

## Benefits Summary

### Development Mode ⚡
- **Speed**: 10x faster iteration
- **Feedback**: Instant (1-2 seconds)
- **Debugging**: Better error messages
- **Productivity**: Stay in flow state

### Production Mode 🏗️
- **Accuracy**: Tests real deployment
- **Performance**: Optimized build
- **Confidence**: Same as cloud
- **Validation**: Catch build issues

---

## Best Practices

✅ **DO:**
- Use dev mode for all active coding
- Test in production mode before committing
- Commit frequently while in dev mode
- Keep dev mode running while working

❌ **DON'T:**
- Deploy dev configuration to cloud
- Assume dev build == production build
- Skip production mode testing
- Commit without testing production build

---

## What's Next?

1. **Start coding!** 🚀
   ```bash
   ./deploy-local.sh dev
   ```

2. **Edit files** in your favorite editor (VSCode, Sublime, etc.)

3. **Save** and watch your browser update automatically! ✨

4. **Test in production mode** before committing:
   ```bash
   ./deploy-local.sh stop
   ./deploy-local.sh deploy
   ```

5. **Deploy to cloud** when ready! ☁️

---

**Happy Coding! 🎉**

For more details, see the [Development Workflow Guide](./Development_Workflow_Guide.md).
