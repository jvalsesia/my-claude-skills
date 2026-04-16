#!/usr/bin/env bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE {{PROJECT_DB_NAME}}_test'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '{{PROJECT_DB_NAME}}_test')\gexec
EOSQL
