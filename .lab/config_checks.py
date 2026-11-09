"""Static checks of the rendered Compose configuration. Prints PASS/FAIL lines, used by verify.sh."""

import json
import subprocess
import sys

CORE = ["web", "api", "worker", "db", "redis"]


def render(*files):
    cmd = ["docker", "compose"]
    for f in files:
        cmd += ["-f", f]
    cmd += ["--profile", "*", "config", "--format", "json"]
    out = subprocess.run(cmd, capture_output=True, text=True)  # noqa: S603
    if out.returncode != 0:
        print("FAIL  the configuration renders (docker compose config):", out.stderr.strip().splitlines()[-1:] or "")
        sys.exit(2)
    return json.loads(out.stdout)


def nets(svc):
    n = svc.get("networks")
    return set(n) if isinstance(n, (dict, list)) else set()


def ports(svc):
    return [(p.get("host_ip", ""), str(p.get("published", "")), p.get("target")) for p in svc.get("ports", [])]


def check(desc, ok):
    print(("PASS  " if ok else "FAIL  ") + desc)


dev = render("compose.yaml", "compose.override.yaml")
prod = render("compose.yaml", "compose.prod.yaml")
base = render("compose.yaml")
s = base.get("services", {})

check("the five services exist: web, api, worker, db, redis", all(c in s for c in CORE))
if not all(c in s for c in CORE):
    sys.exit(1)
check("the project is named 'pollie'", base.get("name") == "pollie")
check("adminer and seed exist and belong to a profile (they do not start by default)", all(s.get(x, {}).get("profiles") for x in ("adminer", "seed")))
check("the five core services are NOT in a profile", not any(s[c].get("profiles") for c in CORE))
check("every core service has a healthcheck", all(s[c].get("healthcheck", {}).get("test") for c in CORE))


def waits_for(svc, dep):
    d = s[svc].get("depends_on", {})
    return isinstance(d, dict) and d.get(dep, {}).get("condition") == "service_healthy"


check("api waits for db and redis to be HEALTHY (not just started)", waits_for("api", "db") and waits_for("api", "redis"))
check("worker waits for db and redis to be healthy", waits_for("worker", "db") and waits_for("worker", "redis"))
check("web waits for the api to be healthy", waits_for("web", "api"))
check("db is on the backend network only", nets(s["db"]) == {"backend"})
check("redis and worker are on the backend network only", nets(s["redis"]) == {"backend"} and nets(s["worker"]) == {"backend"})
check("web is on the frontend network only", nets(s["web"]) == {"frontend"})
check("api is on both networks", nets(s["api"]) == {"backend", "frontend"})
vols = [(v.get("source"), v.get("target"), v.get("type")) for v in s["db"].get("volumes", [])]
check("db stores its data in a named volume (pgdata)", any(t == "/var/lib/postgresql/data" and ty == "volume" for _, t, ty in vols))
check("api and worker use the same image; the worker command is python -m pollie.worker",
      s["api"].get("image") == s["worker"].get("image") and s["worker"].get("command") == ["python", "-m", "pollie.worker"])
check("every core service rotates its logs (max-size)", all(s[c].get("logging", {}).get("options", {}).get("max-size") for c in CORE))
text = open("compose.yaml").read()
check("the database password is not written in compose.yaml (it comes from .env)", "devpass" not in text and "POSTGRES_PASSWORD" in text)

dsvc = dev["services"]
check("DEV: web is published on 127.0.0.1:8080", ("127.0.0.1", "8080", 80) in ports(dsvc["web"]))
check("DEV: the database is published on 127.0.0.1:15432 (for your local tools)", ("127.0.0.1", "15432", 5432) in ports(dsvc["db"]))
check("DEV: adminer is published on 127.0.0.1:8081", ("127.0.0.1", "8081", 8080) in ports(dsvc["adminer"]))
psvc = prod["services"]
check("PROD: only web publishes a port", ports(psvc["web"]) and not any(ports(psvc[c]) for c in ("api", "worker", "db", "redis")))
check("PROD: every core service restarts 'always'", all(psvc[c].get("restart") == "always" for c in CORE))


def limited(svc):
    return bool(svc.get("mem_limit") or svc.get("deploy", {}).get("resources", {}).get("limits", {}).get("memory"))


check("PROD: api, worker and db have a memory limit", all(limited(psvc[c]) for c in ("api", "worker", "db")))
check("PROD: the development override is not applied (api has no DEBUG logging)", psvc["api"].get("environment", {}).get("LOG_LEVEL") != "debug")
