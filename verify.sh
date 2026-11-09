#!/usr/bin/env bash
# Run with: ./verify.sh   (it runs your Compose files: up, tests, down, up again, production mode)
set -u
cd "$(dirname "$0")"
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
[ -d pollie ] || { echo "Run ./setup.sh first"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is needed for the configuration checks"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
API=http://127.0.0.1:8080/api
DEV="docker compose"
PROD="docker compose -f compose.yaml -f compose.prod.yaml"
finish() { $DEV --profile '*' down >/dev/null 2>&1; $PROD down >/dev/null 2>&1; }
trap finish EXIT
$DEV --profile '*' down >/dev/null 2>&1

echo "== The files =="
check ".env exists and is ignored by git" bash -c "[ -f .env ] && git check-ignore -q .env"
check "compose.yaml is valid" bash -c "docker compose config -q"
out=$(python3 .lab/config_checks.py 2>&1); rc=$?
echo "$out"
p=$(grep -c '^PASS' <<<"$out"); f=$(grep -c '^FAIL' <<<"$out"); pass=$((pass+p)); failn=$((failn+f)); total=$((total+p+f))
if [ "$rc" -ne 0 ]; then echo; echo "$failn check(s) failed, $pass passed (fix the configuration first; nothing was started)"; exit 1; fi

echo "== Start from nothing =="
check "docker compose up -d --wait: everything starts and turns healthy" bash -c "docker compose up -d --wait --timeout 180"
check "exactly five services run (the tools and seed profiles did not start)" bash -c "[ \$(docker compose ps --services --status running | wc -l) -eq 5 ]"
check "the very first request after --wait already works (no 502 while things start)" bash -c "curl -sf --max-time 5 http://127.0.0.1:8080/api/readyz"
check "http://localhost:8080 serves the Pollie web app" bash -c "curl -s --max-time 5 http://127.0.0.1:8080/ | grep -qi pollie"
check "the api can reach the database and Redis" bash -c "docker compose exec -T api python -c \"import socket; socket.create_connection(('db',5432),2); socket.create_connection(('redis',6379),2)\""
check "the web service cannot reach the database" bash -c "! docker compose exec -T web nc -z -w 2 db 5432"

e2e() {
  local p pid oid body code
  p=$(curl -s --max-time 5 -XPOST "$API/polls" -H 'Content-Type: application/json' -d '{"question":"Compose?","options":["yes","no"]}')
  pid=$(sed -E 's/^\{"id":([0-9]+).*/\1/' <<<"$p"); oid=$(grep -oE '"options":\[\{"id":[0-9]+' <<<"$p" | grep -oE '[0-9]+$')
  [ -n "$pid" ] && [ -n "$oid" ] || return 1
  echo "$pid" > /tmp/pollie-compose-poll
  body=$(printf '{"option_id":%s,"voter_id":"v1"}' "$oid")
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -XPOST "$API/polls/$pid/votes" -H 'Content-Type: application/json' -d "$body")
  [ "$code" = 202 ] || return 1
  for _ in $(seq 20); do sleep 1; curl -s --max-time 5 "$API/polls/$pid/results" | grep -q '"total_votes":1' && return 0; done
  return 1
}
check "end to end: create a poll, vote, the worker records it" e2e

echo "== Profiles =="
check "--profile tools starts adminer and it answers on http://localhost:8081" bash -c "docker compose --profile tools up -d --wait adminer && for i in \$(seq 15); do [ \"\$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8081/)\" = 200 ] && exit 0; sleep 1; done; exit 1"
check "adminer can be stopped without touching the rest" bash -c "docker compose --profile tools stop adminer && [ \$(docker compose ps --services --status running | wc -l) -eq 5 ]"
count() { curl -s --max-time 5 "$API/polls" | grep -o '"question"' | wc -l | tr -d ' '; }
before=$(count)
check "--profile seed run --rm seed creates the three sample polls" bash -c "docker compose --profile seed run --rm seed | grep -c created | grep -q 3"
check "the polls are really there afterwards (+3)" bash -c "[ \"\$(curl -s --max-time 5 $API/polls | grep -o '\"question\"' | wc -l | tr -d ' ')\" -ge $((before+3)) ]"

echo "== Down is not destroy =="
pid=$(cat /tmp/pollie-compose-poll 2>/dev/null || echo 0)
check "docker compose down removes the containers and the networks" bash -c "docker compose --profile '*' down && [ -z \"\$(docker ps -a -q --filter label=com.docker.compose.project=pollie)\" ]"
check "...but the volume (the data) is still there" bash -c "docker volume ls -q --filter label=com.docker.compose.project=pollie | grep -q pgdata"
check "up again: the poll created before 'down' is still there" bash -c "docker compose up -d --wait --timeout 180 && curl -s --max-time 5 $API/polls/$pid | grep -q 'Compose?'"

echo "== Production mode =="
check "the production stack starts with -f compose.yaml -f compose.prod.yaml" bash -c "docker compose --profile '*' down && $PROD up -d --wait --timeout 180"
check "production: only the web container has published ports" bash -c "[ -z \"\$(docker port pollie-db-1)\$(docker port pollie-api-1)\$(docker port pollie-redis-1)\$(docker port pollie-worker-1)\" ] && [ -n \"\$(docker port pollie-web-1)\" ]"
check "production: restart policy is 'always' and the memory limit is applied" bash -c "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' pollie-api-1)\" = always ] && [ \"\$(docker inspect -f '{{.HostConfig.Memory}}' pollie-api-1)\" -gt 0 ]"
check "production still serves the app and the data is still there" bash -c "curl -s --max-time 5 http://127.0.0.1:8080/api/polls/$pid | grep -q 'Compose?'"

echo
if [ "$failn" -eq 0 ]; then echo "ALL CHECKS PASSED ($pass/$total)"; else echo "$failn check(s) failed, $pass passed"; fi
exit "$failn"
