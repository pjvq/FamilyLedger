#!/bin/sh
set -e

echo "Running database migrations..."
migrate -path /app/migrations -database "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DB_NAME}?sslmode=${DB_SSLMODE:-disable}" up

echo "Starting server..."
exec /app/server
