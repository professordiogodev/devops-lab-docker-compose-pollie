# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `compose.yaml`: the base stack
- [ ] `compose.override.yaml`: development settings
- [ ] `compose.prod.yaml`: production settings

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Compare your `compose.yaml` to the `stack.sh` you wrote last time. What did Compose do for you that the script did by hand? What does running `docker compose up -d` a second time do when nothing changed, and when you changed one service?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. You tried `depends_on` without `condition: service_healthy`. Paste the status codes your probe loop printed in the first seconds and the API log lines from while PostgreSQL was starting. Why does "started" not mean "ready", and what does `up -d --wait` give a pipeline?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. For each of your five health checks: the command, and why that command is a good test of that service. What do `interval`, `timeout`, `retries` and `start_period` do, and what would go wrong with `start_period` too short?

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Why do `adminer` and `seed` live under profiles? Paste the output of `docker compose ps` with and without `--profile tools`. What is the difference between `docker compose run --rm seed` and a service that is always up?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. Paste the part of `docker compose config` (dev) and `docker compose -f compose.yaml -f compose.prod.yaml config` (prod) that differs for the `db` service. Why must production not publish the database port? What happens when two files define the same list key (`ports`) and when they define the same scalar key (`restart`)?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Paste the result of `docker compose down` followed by `docker volume ls`, and then of `docker compose down -v`. What does each remove? When is `-v` the right command and when is it a disaster?

**Your answer:**

<!-- replace this line with your answer -->

### Q7. The database password is not in `compose.yaml`. Where does it come from, what stops it from being committed, and what is still not safe about this approach for real production? (Name one better option.)

**Your answer:**

<!-- replace this line with your answer -->

### Q8. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q9. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
