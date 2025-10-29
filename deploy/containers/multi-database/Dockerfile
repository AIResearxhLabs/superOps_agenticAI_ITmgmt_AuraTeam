# Multi-Database Container for Cost Optimization
# Combines PostgreSQL, MongoDB, and Redis in a single container
FROM ubuntu:22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install essential packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    lsb-release \
    supervisor \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL
RUN apt-get update && apt-get install -y \
    postgresql-14 \
    postgresql-contrib-14 \
    && rm -rf /var/lib/apt/lists/*

# Install MongoDB
RUN wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | apt-key add - \
    && echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list \
    && apt-get update \
    && apt-get install -y mongodb-org \
    && rm -rf /var/lib/apt/lists/*

# Install Redis
RUN apt-get update && apt-get install -y \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# Create directories for databases
RUN mkdir -p /var/lib/postgresql/data \
    && mkdir -p /data/db \
    && mkdir -p /data/redis \
    && mkdir -p /var/log/supervisor

# Set up PostgreSQL
RUN service postgresql start \
    && su - postgres -c "createuser -s aura_user" \
    && su - postgres -c "psql -c \"ALTER USER aura_user PASSWORD 'aura_password';\"" \
    && su - postgres -c "createdb -O aura_user aura_servicedesk" \
    && su - postgres -c "createdb -O aura_user aura_infratalent" \
    && su - postgres -c "createdb -O aura_user aura_threatintel" \
    && service postgresql stop

# Configure PostgreSQL
RUN echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/14/main/pg_hba.conf \
    && echo "listen_addresses='*'" >> /etc/postgresql/14/main/postgresql.conf

# Configure MongoDB
RUN mkdir -p /data/db \
    && chown -R mongodb:mongodb /data/db

# Configure Redis
RUN sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf \
    && sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY init-databases.sh /docker-entrypoint-initdb.d/init-databases.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-databases.sh

# Expose all database ports
EXPOSE 5432 27017 6379

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -h localhost -p 5432 -U aura_user && \
        redis-cli -h localhost -p 6379 ping && \
        mongosh --host localhost:27017 --eval "db.adminCommand('ping')" || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
