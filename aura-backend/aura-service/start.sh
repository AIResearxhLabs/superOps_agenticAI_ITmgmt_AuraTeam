#!/bin/bash

# Aura Unified Service Startup Script

set -e

echo "🚀 Starting Aura Unified Service..."

# Wait for databases to be ready
echo "⏳ Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST:-localhost} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-aura_user} > /dev/null 2>&1; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
done
echo "✅ PostgreSQL is ready"

echo "⏳ Waiting for Redis..."
until redis-cli -h ${REDIS_HOST:-localhost} -p ${REDIS_PORT:-6379} ping > /dev/null 2>&1; do
    echo "Redis is unavailable - sleeping"
    sleep 2
done
echo "✅ Redis is ready"

echo "⏳ Waiting for MongoDB..."
until mongosh --host ${MONGO_HOST:-localhost}:${MONGO_PORT:-27017} --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    echo "MongoDB is unavailable - sleeping"
    sleep 2
done
echo "✅ MongoDB is ready"

# Initialize databases if needed
echo "📊 Checking database initialization..."
if [ "$INIT_DB" = "true" ]; then
    echo "Initializing database schema..."
    python -c "
from shared.utils.database import init_database
import asyncio
asyncio.run(init_database())
print('✅ Database schema initialized')
"
fi

# Populate sample data if requested
if [ "$POPULATE_DATA" = "true" ]; then
    echo "📝 Populating sample data..."
    cd /app/servicedesk && python populate_knowledge_base.py
    echo "✅ Sample data populated"
fi

# Start the unified service
echo "🎯 Starting Aura Unified Service on port ${PORT:-8000}..."
exec uvicorn main:app \
    --host ${HOST:-0.0.0.0} \
    --port ${PORT:-8000} \
    --log-level ${LOG_LEVEL:-info} \
    --access-log \
    --no-server-header
