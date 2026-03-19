#!/bin/bash

echo "==> Stopping Phoenix server..."
lsof -ti:4000 | xargs kill -9 2>/dev/null && echo "    Server stopped" || echo "    No server running"

echo "==> Stopping PostgreSQL..."
docker compose down 2>/dev/null && echo "    PostgreSQL stopped" || echo "    No containers running"

echo ""
echo "Done. Colima still running (use 'colima stop' to stop it)."
