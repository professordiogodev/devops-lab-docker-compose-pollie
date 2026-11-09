#!/bin/sh
# Provided. Creates three sample polls through the API. Used by the "seed" service.
set -e
API="${API_URL:-http://api:8000}"
post() { curl -sf -X POST "$API/polls" -H 'Content-Type: application/json' -d "$1" >/dev/null && echo "created: $2"; }
post '{"question":"Tabs or spaces?","options":["Tabs","Spaces"]}' "Tabs or spaces?"
post '{"question":"Best deploy day?","options":["Monday","Wednesday","Friday (brave)"]}' "Best deploy day?"
post '{"question":"Is it DNS?","options":["It is always DNS","It was not DNS"]}' "Is it DNS?"
