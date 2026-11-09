#!/usr/bin/env bash
# Removes everything the lab created. Run:  ./teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
# stop and remove the project (all profiles), its volumes and the images it built
if [ -s compose.yaml ]; then docker compose --profile '*' down -v --remove-orphans >/dev/null 2>&1; fi
docker compose -p pollie --profile '*' down -v --remove-orphans >/dev/null 2>&1 || true
ids=$(docker ps -a -q --filter label=com.docker.compose.project=pollie)
[ -n "$ids" ] && docker rm -f -v $ids >/dev/null
docker volume ls -q --filter label=com.docker.compose.project=pollie | xargs -r docker volume rm >/dev/null 2>&1 || true
docker network ls -q --filter label=com.docker.compose.project=pollie | xargs -r docker network rm >/dev/null 2>&1 || true
docker rmi -f pollie:lab4 >/dev/null 2>&1 || true
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^pollie[:-]' | xargs -r docker rmi -f >/dev/null 2>&1 || true
rm -rf pollie
echo "Removed the pollie project (containers, networks, volumes), its images and the cloned source. Now run ./verify-teardown.sh to prove it."
echo "(Your compose files, .env and answers stay: they are your submission. adminer, curl and the base images are a cache.)"
