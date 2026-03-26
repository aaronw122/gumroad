# Autoresearch: CI Speed Optimization

## Objective
Reduce the total wall-clock time of the GitHub Actions CI pipeline (`tests.yml`) from ~18 minutes to ≤14 minutes. The pipeline builds Docker images and runs Ruby/RSpec tests in parallel across multiple nodes using Knapsack Pro.

## Metrics
- **Primary**: wall_clock_min (min, lower is better)

## How to Run
`autoresearch.sh` — should emit `METRIC name=number` lines for wall_clock_min.

## Files in Scope
- `.github/workflows/tests.yml` — CI workflow: jobs, parallelization, retry logic, runner config
- `docker/web/Dockerfile.test` — test image build (COPY app, chmod, env setup)
- `docker/docker-compose-test-and-ci.yml` — service definitions (MySQL, Redis, ES, Minio, Mongo, Memcached)
- `docker/ci/wait_on_connection.sh` — health check script for services
- `Makefile` — Docker build targets (build_base, build_base_test, build_test)
- `docker/base/Dockerfile` — base image (Ruby, gems)
- `docker/base/Dockerfile.test` — test base image (Chrome, system deps)

## Off Limits
- Test files (`spec/**`) — do not remove or skip tests
- Application code (`app/**`, `lib/**`) — do not modify
- Gemfile/Gemfile.lock — do not change dependencies
- Runner type (`runs-on:`) — keep current runners, do not switch to more expensive instances

## Constraints
- **No test coverage reduction** — all existing tests must still run
- **Ubicloud cost control** — total runner-minutes should not increase more than ~20% over baseline
- **Tests must pass** — a run only counts if CI is green
- Current config: 20 fast nodes + 55 slow nodes on `ubicloud-standard-4` (4 vCPU)
- Build uses content-addressed caching — base/test-base images skip rebuild if unchanged
- Knapsack Pro dynamically balances test distribution across nodes

## What's Been Tried
- Increased parallelization: fast 15→20, slow 45→55 (30.7min → 18.8min)
- Merged build_base + build_test into single job (18.8min → 17.1min)
- Enabled DOCKER_BUILDKIT=1
- Added nick-fields/retry for Start/Wait services
- Added Elasticsearch health check to wait_on_connection.sh

## What's Been Tried
- No logged experiments yet.

## Plugin Checkpoint
- Last updated: 2026-03-26T19:44:19.867Z
- Runs tracked: 0 current / 0 total
- Baseline: n/a
- Best kept: n/a
- Confidence: n/a
- Canonical branch: autoresearch/ci-speed-2026-03-26
