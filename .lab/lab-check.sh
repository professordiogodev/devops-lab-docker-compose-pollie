#!/usr/bin/env bash
rc=0
for f in compose.yaml compose.override.yaml compose.prod.yaml; do
  if [ -s "$f" ] && ! grep -q '^services: {}' "$f"; then echo "- ✅ $f is written"; else echo "- ❌ $f is still the starter"; rc=1; fi
done
grep -q 'service_healthy' compose.yaml 2>/dev/null && echo "- ✅ compose.yaml uses health-based start order" || { echo "- ❌ compose.yaml must use depends_on with condition: service_healthy"; rc=1; }
grep -qE '^ALL CHECKS PASSED \(' SUBMISSION.md && echo "- ✅ SUBMISSION.md shows ALL CHECKS PASSED" || { echo "- ❌ paste the verify.sh output ('ALL CHECKS PASSED') into SUBMISSION.md"; rc=1; }
exit $rc
