#!/usr/bin/env bash
# Prepares the lab: gets Pollie, pulls images, creates .env. Run:  ./setup.sh   (no sudo)
set -uo pipefail
cd "$(dirname "$0")"
command -v docker >/dev/null || { echo "docker is not installed or not on PATH"; exit 1; }
command -v git >/dev/null || { echo "git is not installed"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running (or your user may not use it). Start Docker and try again."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is missing ('docker compose version' fails). Update Docker."; exit 1; }
if [ -d pollie ]; then echo "The lab is already set up. Run ./teardown.sh first to start over."; exit 1; fi
for port in 8080 8081 8000 15432; do
  if (exec 3<>/dev/tcp/127.0.0.1/$port) 2>/dev/null; then echo "Port $port is in use on your machine. Free it first."; exit 1; fi
done
echo "Getting the Pollie source (v0.1.1)..."
git clone -q --depth 1 --branch v0.1.1 https://github.com/professordiogodev/pollie.git pollie 2>/dev/null || { echo "could not clone Pollie (network?)"; exit 1; }
echo "Pulling images (first run only)..."
for img in python:3.12-slim postgres:16-alpine redis:7-alpine nginx:alpine adminer:4 curlimages/curl:8.10.1; do docker pull -q "$img" >/dev/null || { echo "could not pull $img"; exit 1; }; done
[ -f .env ] || cp .env.example .env
echo
echo "Ready. You have:"
echo "  pollie/           the application source (a git clone, do not edit)"
echo "  base/Dockerfile   builds the Pollie image (API and worker)"
echo "  nginx.conf        the web server config for the web service"
echo "  seed/seed.sh      creates sample polls (for the seed service)"
echo "  .env              settings (POSTGRES_PASSWORD, POLLIE_IMAGE)"
echo "  compose.yaml, compose.override.yaml, compose.prod.yaml   the three files YOU write"
