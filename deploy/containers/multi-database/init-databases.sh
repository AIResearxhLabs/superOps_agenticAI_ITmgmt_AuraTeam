#!/bin/bash
# Database initialization script for multi-database container

set -e

echo "🚀 Initializing multi-database container..."

# Start PostgreSQL service temporarily for initialization
service postgresql start
sleep 5

# Initialize PostgreSQL databases
echo "📊 Setting up PostgreSQL databases..."
su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE USER aura_user WITH SUPERUSER PASSWORD 'aura_password';
    CREATE DATABASE aura_servicedesk OWNER aura_user;
    CREATE DATABASE aura_infratalent OWNER aura_user;
    CREATE DATABASE aura_threatintel OWNER aura_user;
    GRANT ALL PRIVILEGES ON DATABASE aura_servicedesk TO aura_user;
    GRANT ALL PRIVILEGES ON DATABASE aura_infratalent TO aura_user;
    GRANT ALL PRIVILEGES ON DATABASE aura_threatintel TO aura_user;
EOSQL"

# Verify PostgreSQL setup
echo "✅ PostgreSQL databases created successfully"
su - postgres -c "psql -c \"\l\"" | grep aura_

# Stop PostgreSQL service (supervisor will manage it)
service postgresql stop

echo "🎯 Multi-database initialization completed!"
