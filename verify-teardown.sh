#!/usr/bin/env bash
# Proves the lab environment is gone. Run with: ./verify-teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
none() { [ -z "$(eval "$1")" ]; }
check "no container of the compose project 'pollie'" none "docker ps -a -q --filter label=com.docker.compose.project=pollie"
check "no network of the project" none "docker network ls -q --filter label=com.docker.compose.project=pollie"
check "no volume of the project (the database data is gone)" none "docker volume ls -q --filter label=com.docker.compose.project=pollie"
check "no image pollie:*" none "docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^pollie[:-]'"
check "the cloned source ./pollie is removed" bash -c "[ ! -e pollie ]"
check "ports 8080 and 8081 are free" bash -c "! (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null && ! (exec 3<>/dev/tcp/127.0.0.1/8081) 2>/dev/null"
echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$total)"; else echo "NOT CLEAN: $failn leftover(s). Finish the tear down steps and run this again."; fi
exit "$failn"
