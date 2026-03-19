#!/bin/bash
set -e

echo "==> Checking Colima..."
if ! colima status &>/dev/null; then
  echo "==> Starting Colima..."
  colima start
else
  echo "    Colima already running"
fi

echo "==> Starting PostgreSQL..."
docker compose up db -d

echo "==> Waiting for PostgreSQL..."
until docker exec argentic-ui-framework-db-1 pg_isready -U postgres &>/dev/null; do
  sleep 1
done
echo "    PostgreSQL ready"

echo "==> Running migrations..."
mix ecto.create -r AgenticUi.Repo 2>/dev/null || true
mix ecto.migrate -r AgenticUi.Repo

echo "==> Killing previous server (if any)..."
lsof -ti:4000 | xargs kill -9 2>/dev/null || true
sleep 1

echo "==> Starting Phoenix server (logs: /tmp/phx-server.log)..."
mix phx.server > /tmp/phx-server.log 2>&1 &

sleep 3
echo ""
echo "Ready! http://localhost:4000"
echo "Logs:  tail -f /tmp/phx-server.log"
