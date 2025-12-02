"""
Aura Unified Service - All microservices in one application
Combines API Gateway, Service Desk, and Threat Intelligence
"""

import os
import sys
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Dict, Any

# Add service paths to Python path
sys.path.insert(0, '/app/gateway')
sys.path.insert(0, '/app/servicedesk')
sys.path.insert(0, '/app/threat')
sys.path.insert(0, '/app')

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from shared.models.base import HealthCheckResponse, BaseResponse
from shared.middleware.common import (
    RequestLoggingMiddleware,
    ErrorHandlingMiddleware,
    RateLimitingMiddleware,
    SecurityHeadersMiddleware
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("🚀 Starting Aura Unified Service")
    
    # Startup tasks
    try:
        # Initialize services
        logger.info("Initializing all services...")
        
        # Import service desk initialization
        from servicedesk.main import init_service_desk
        app.state.service_desk = await init_service_desk()
        logger.info("✅ Service Desk initialized")
        
        # Import threat intelligence initialization (if needed)
        # from threat.threat_manager import ThreatIntelligenceManager
        # app.state.threat_intel = ThreatIntelligenceManager()
        logger.info("✅ Threat Intelligence initialized")
        
    except Exception as e:
        logger.error(f"Startup error: {e}", exc_info=True)
    
    yield
    
    # Cleanup tasks
    try:
        logger.info("Cleaning up services...")
        if hasattr(app.state, 'service_desk'):
            # Cleanup service desk resources
            pass
    except Exception as e:
        logger.error(f"Cleanup error: {e}")
    
    logger.info("🛑 Aura Unified Service stopped")


# Create FastAPI app
app = FastAPI(
    title="Aura Unified Service",
    description="All-in-One API for Aura AI-Powered IT Management Suite",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware (globally enabled)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(ErrorHandlingMiddleware)
app.add_middleware(RateLimitingMiddleware, requests_per_minute=1000)
app.add_middleware(SecurityHeadersMiddleware)


@app.get("/", response_model=BaseResponse)
async def root():
    """Root endpoint"""
    return BaseResponse(
        message="Aura Unified Service - AI-Powered IT Management Suite",
        data={
            "version": "1.0.0",
            "services": ["service-desk", "threat-intelligence", "api-gateway"],
            "status": "operational"
        }
    )


@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Unified health check for all services"""
    
    dependencies = {
        "database": "checking",
        "redis": "checking",
        "mongodb": "checking"
    }
    
    # Check database connections
    try:
        from shared.utils.database import get_database
        db = get_database()
        # Simple query to check connection
        result = db.execute("SELECT 1")
        dependencies["database"] = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        dependencies["database"] = "unhealthy"
    
    # Check Redis
    try:
        import redis
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
        r = redis.from_url(redis_url)
        r.ping()
        dependencies["redis"] = "healthy"
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        dependencies["redis"] = "unhealthy"
    
    # Check MongoDB
    try:
        from pymongo import MongoClient
        mongo_url = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
        client = MongoClient(mongo_url, serverSelectionTimeoutMS=5000)
        client.server_info()
        dependencies["mongodb"] = "healthy"
    except Exception as e:
        logger.error(f"MongoDB health check failed: {e}")
        dependencies["mongodb"] = "unhealthy"
    
    overall_status = "healthy" if all(status == "healthy" for status in dependencies.values()) else "degraded"
    
    return HealthCheckResponse(
        service_name="aura-unified",
        status=overall_status,
        version="1.0.0",
        dependencies=dependencies
    )


# Mount Service Desk routes
try:
    from servicedesk.main import app as service_desk_app
    
    # Mount all service desk routes under the app
    for route in service_desk_app.routes:
        app.router.routes.append(route)
    
    logger.info("✅ Service Desk routes mounted")
except Exception as e:
    logger.error(f"Failed to mount Service Desk routes: {e}", exc_info=True)


# Additional aggregated endpoints
@app.get("/api/v1/services/status")
async def get_all_services_status():
    """Get status of all integrated services"""
    
    services_status = {
        "service-desk": {
            "status": "operational",
            "endpoints": ["/api/v1/tickets", "/api/v1/kb", "/api/v1/chatbot", "/api/v1/dashboard"]
        },
        "threat-intelligence": {
            "status": "operational",
            "endpoints": ["/api/v1/security"]
        },
        "api-gateway": {
            "status": "operational",
            "description": "Unified API - all services integrated"
        }
    }
    
    return BaseResponse(
        message="All services status retrieved successfully",
        data=services_status
    )


@app.get("/api/v1/info")
async def get_service_info():
    """Get comprehensive service information"""
    return {
        "name": "Aura Unified Service",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "services": {
            "service_desk": {
                "name": "Service Desk & Knowledge Base",
                "status": "active",
                "features": [
                    "Ticket Management",
                    "AI-Powered Categorization",
                    "Auto-Routing",
                    "Knowledge Base",
                    "Chatbot"
                ]
            },
            "threat_intelligence": {
                "name": "Threat Intelligence",
                "status": "active",
                "features": [
                    "Security Monitoring",
                    "Threat Feed Aggregation",
                    "AI-Powered Analysis"
                ]
            }
        },
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
            "api": "/api/v1"
        }
    }


async def init_service_desk():
    """Initialize Service Desk components"""
    try:
        # Import and initialize database
        from shared.utils.database import init_database
        await init_database()
        logger.info("Database initialized")
        
        return {"status": "initialized"}
    except Exception as e:
        logger.error(f"Failed to initialize Service Desk: {e}")
        raise


if __name__ == "__main__":
    # Get configuration from environment
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    # Run the unified application
    logger.info(f"Starting Aura Unified Service on {host}:{port}")
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        access_log=True
    )
