# LAB | Compose Pollie: One File, Three Environments

## The situation

Welcome to the team chat of your second week. This is what you find when you scroll up:

```text
#pollie-dev                                                        Mon 16:20
joana    I started the API and it crashed. is the database broken?
rui      no, you started it before postgres was ready. happens every week
joana    ok, I also opened the db port "just to debug" and forgot about it
rui      ...it has been open to the whole office wifi since Wednesday
lead     enough. one file. docker compose up and it works, in the right order,
         on a clean machine. devs get ports and debug logs. production
         publishes ONE port, restarts always and has limits.
         and I want sample data on demand without it running all day.
lead     @you
```

Last week's Pollie stack worked, and then a new colleague tried to run it. You will write that file (and its two siblings), then break the start order on purpose to see why the details matter. The work has two acts: **Act 1** is the developer's file and a working day with it; after an **interval** (a message from the release meeting), **Act 2** is production, and the proof that `down` is not `destroy`.

> **Your mission**
> - Describe the whole Pollie stack in `compose.yaml`, with health checks and an honest start order
> - Add developer conveniences that are **off** by default (Adminer, sample data) using profiles
> - Write a development override and a production override from the same base
> - Prove that `down` keeps your data and that `down -v` does not
> - Tear down everything and prove it

**Time:** 90-105 min | **Cost:** free | **You need:** Docker with Compose v2, git, python3, a terminal. `./teardown.sh` removes the lab.

---

## Part 0 - Act 1: set the scene

Fork this repository, clone your fork, and run:

```bash
./setup.sh
```

You get the Pollie source in `./pollie`, a `base/Dockerfile` that builds the image for the API and the worker, `nginx.conf` for the web service, `seed/seed.sh` (creates three sample polls through the API), a `.env` with the settings, and three **empty** files for you to write: `compose.yaml`, `compose.override.yaml`, `compose.prod.yaml`.

---

## Part 1 - Recon: read what you already know

Open your `stack.sh` from the previous lab if you have it (or the picture below) and list, for each of the five containers: image, network(s), volume, environment variables, command, restart policy and published port. That list **is** your Compose file; only the syntax changes.

```text
web    -> frontend            nginx.conf and pollie/web mounted read only
api    -> frontend + backend  image built from pollie/ using base/Dockerfile
worker -> backend             the same image, command: python -m pollie.worker
db     -> backend             volume for /var/lib/postgresql/data
redis  -> backend
```

> **Predict** If you run `docker compose up -d` on a cold machine and everything has plain `depends_on`, can a user open the site the moment the command returns? Think about what "started" means for PostgreSQL. Keep your answer; you will test it in Part 3.

---

## Part 2 - Write `compose.yaml`

Requirements (`./verify.sh` checks every one by rendering your configuration with `docker compose config`):

| Requirement | Why |
|-------------|-----|
| `name: pollie` at the top | Predictable container, network and volume names |
| Services `web`, `api`, `worker`, `db`, `redis`; the API and worker use **one** image built from `pollie/` with `../base/Dockerfile` | One build, two jobs |
| A `healthcheck` on every service | `pg_isready`, `redis-cli ping`, and for the Python services an HTTP check using the Python already in the image |
| `depends_on` with `condition: service_healthy`: api and worker wait for db and redis; web waits for api | "Started" is not "ready" |
| Networks `frontend` and `backend` as in the picture: db and redis only on backend, web only on frontend, api on both | Isolation |
| A **named volume** `pgdata` for the database | Data survives the container |
| The database password comes from `.env` (`${POSTGRES_PASSWORD}`) and is **not** written in the file; `.env` is ignored by git | Secrets stay out of git |
| Logs rotate on every core service (`logging` with `max-size`) | Remember the noisy neighbour? |
| `restart: unless-stopped` on the core services | Survive crashes and reboots |
| `adminer` (profile `tools`) and `seed` (profile `seed`, runs `seed/seed.sh` with the `curlimages/curl` image) | Tools off by default |

No ports are published in the base file. That is deliberate: **ports are an environment decision**.

Useful: YAML anchors and `x-` extension fields let you write shared settings once (logging, the Pollie image and environment).

```bash
docker compose config        # shows the file Compose really sees, with variables filled in
docker compose up -d --wait  # --wait blocks until every service is healthy
docker compose ps
docker compose logs -f worker
```

> **Checkpoint** `docker compose up -d --wait` ends with every container `Healthy`, and (after Part 4) `http://localhost:8080` shows Pollie.

---

## Part 3 - Break the start order

Run this experiment twice, once with your health-based `depends_on`, once with plain "started" ordering:

1. `docker compose down -v`. Change every `condition: service_healthy` to `condition: service_started` (or use the short `depends_on: [db, redis]` form).
2. Start and probe immediately, as a user would:

```bash
docker compose up -d
for i in $(seq 15); do curl -s -o /dev/null -w '%{http_code} ' localhost:8080/api/readyz; sleep 1; done; echo
docker compose logs api | head -20
```

3. Put the `service_healthy` conditions back, `docker compose down -v`, and run `docker compose up -d --wait`, then one `curl localhost:8080/api/readyz`.

Compare the two. What did the user see in the first seconds? What did the API log while PostgreSQL was still starting? (Pollie's connection pool is patient, so it recovered by itself. Many applications are not: they crash, and a restart policy hides it.)

> **Think** `up -d` returned immediately both times. What does `--wait` give you that `up -d` does not, and why does a deployment pipeline want it? Why is "it eventually works" not good enough in production?

---

## Part 4 - Development: `compose.override.yaml`

Compose merges `compose.override.yaml` into `compose.yaml` **automatically**. Use it for what developers want:

| Service | What to add |
|---------|-------------|
| `web` | publish `127.0.0.1:8080` to port 80 |
| `api` | publish `127.0.0.1:8000`, and `LOG_LEVEL=debug` |
| `db` | publish `127.0.0.1:15432` to 5432, so your local tools can connect |
| `adminer` | publish `127.0.0.1:8081` to its port 8080 |

Start the stack and use it:

1. `http://localhost:8080`: create a poll and vote. Watch the worker: `docker compose logs -f worker`.
2. `docker compose --profile tools up -d adminer`, open `http://localhost:8081` (system PostgreSQL, server `db`, user `postgres`, password from `.env`, database `pollie`). Find your vote in the `votes` table.
3. `docker compose --profile seed run --rm seed`, then reload the page.

> **Predict** After step 2, how many containers does `docker compose ps` list? Is Adminer part of the default `docker compose up`?

---

## Interval - Thursday, the release meeting

The lead walks back from the release meeting: *"Good news: your stack runs on every laptop. Bad news: the release is tomorrow, and the production server has 2 GB of memory and the security team will look at its open ports. Same files, different behaviour, please."*

---

## Part 5 - Production: `compose.prod.yaml`

Production does not use the override file; you name the files explicitly:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d --wait
```

| Requirement |
|-------------|
| Only `web` publishes a port (80 inside, 8080 outside is fine for this lab) |
| `restart: always` on the core services |
| Memory limits on `api`, `worker` and `db` (and CPU limits on `api` and `worker`) |
| No debug logging |

Compare what Compose sees: `docker compose config` and `docker compose -f compose.yaml -f compose.prod.yaml config`.

> **Think** The override file adds ports to a *list*. Why can the production file not simply "remove" a port that the override added? (Recent Compose versions have a `!reset` tag, but not loading the override at all is simpler and safer.) What does that tell you about why prod should not load the override file?

---

## Part 6 - Down is not destroy

```bash
docker compose down        # containers and networks go away
docker volume ls           # pollie_pgdata is still here
docker compose up -d --wait
```

Is your poll still there? Then, only when you really mean it: `docker compose down -v` deletes the volumes too. Do it **after** `./verify.sh`.

---

## Part 7 - Prove it

```bash
./verify.sh
```

It checks your three files (about 25 static checks), starts the stack from nothing, tests isolation, a vote end to end, both profiles, `down` versus data, and finally production mode. Fix what is red and run it again until it ends with **ALL CHECKS PASSED**.

> **Stuck?** `docker compose config` tells you exactly what Compose understood, including mistakes in indentation. Health check commands run **inside** the container: use tools that exist there. In YAML, `<<: *anchor` merges a mapping, and keys you write next to it win.

---

## Level up (optional)

- Use `docker compose watch` (`develop.watch`) to rebuild the API when source files change.
- Pass the password with Compose `secrets:` and a file instead of an environment variable. What does `docker inspect` show now?
- Add a second worker with `docker compose up -d --scale worker=3`. Do the votes still count once?

<!-- teardown:start (generated by labs.py, do not edit) -->
## Tear down (mandatory)

Resources left behind cost money, keep doors open and pollute the next lab. Removing what you created is part of the job, so it is part of the submission: **you must prove it is gone**.

Do this **last**, after you have pasted your `verify` output into `SUBMISSION.md` (once you tear down, the lab can no longer be verified).

1. Run `./teardown.sh`. It runs `docker compose down -v` for every profile, removes the `pollie` images and the cloned source. Your compose files, `.env` and answers stay.

Then run the proof:

```bash
./verify-teardown.sh
```

It prints a list of checks and must end with **TEARDOWN VERIFIED**. If it reports leftovers, remove them and run it again. Paste the full output in your submission.
<!-- teardown:end -->

<!-- submission:start (generated by labs.py, do not edit) -->
## Submission

Answer the questions in `SUBMISSION.md` in **your fork** (paste output in code blocks where asked), push, then submit the **URL of your fork**.

**Files to commit**

- `compose.yaml`: the base stack
- `compose.override.yaml`: development settings
- `compose.prod.yaml`: production settings

**Questions to answer**

1. Compare your `compose.yaml` to the `stack.sh` you wrote last time. What did Compose do for you that the script did by hand? What does running `docker compose up -d` a second time do when nothing changed, and when you changed one service?
2. You tried `depends_on` without `condition: service_healthy`. Paste the status codes your probe loop printed in the first seconds and the API log lines from while PostgreSQL was starting. Why does "started" not mean "ready", and what does `up -d --wait` give a pipeline?
3. For each of your five health checks: the command, and why that command is a good test of that service. What do `interval`, `timeout`, `retries` and `start_period` do, and what would go wrong with `start_period` too short?
4. Why do `adminer` and `seed` live under profiles? Paste the output of `docker compose ps` with and without `--profile tools`. What is the difference between `docker compose run --rm seed` and a service that is always up?
5. Paste the part of `docker compose config` (dev) and `docker compose -f compose.yaml -f compose.prod.yaml config` (prod) that differs for the `db` service. Why must production not publish the database port? What happens when two files define the same list key (`ports`) and when they define the same scalar key (`restart`)?
6. Paste the result of `docker compose down` followed by `docker volume ls`, and then of `docker compose down -v`. What does each remove? When is `-v` the right command and when is it a disaster?
7. The database password is not in `compose.yaml`. Where does it come from, what stops it from being committed, and what is still not safe about this approach for real production? (Name one better option.)
8. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.
9. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.
<!-- submission:end -->
