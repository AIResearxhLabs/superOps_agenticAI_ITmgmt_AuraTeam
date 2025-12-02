FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy shared modules first
COPY shared/ /app/shared/

# Copy unified requirements file (pre-resolved conflicts)
COPY aura-service/requirements.txt /app/requirements.txt

# Install all dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all service code
COPY api-gateway/ /app/gateway/
COPY service-desk-host/ /app/servicedesk/
COPY threat-intelligence-agent/ /app/threat/

# Copy unified main application
COPY aura-service/main.py /app/main.py
COPY aura-service/start.sh /app/start.sh

# Make start script executable
RUN chmod +x /app/start.sh

# Expose ports
EXPOSE 8000 8001 8002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the unified application
CMD ["/app/start.sh"]
