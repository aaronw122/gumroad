#!/bin/bash
set -euo pipefail

# Push current branch and trigger CI, then wait and measure wall-clock time
REPO="antiwork/gumroad"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse HEAD)

echo "Pushing $BRANCH ($SHA)..."
git push -f origin "$BRANCH" 2>&1 | tail -3

# Wait for run to appear
echo "Waiting for CI run to start..."
sleep 15

for i in $(seq 1 10); do
  RUN_ID=$(gh api "repos/$REPO/actions/workflows/tests.yml/runs?branch=$BRANCH&per_page=1&event=push" --jq '.workflow_runs[0] | select(.head_sha == "'"$SHA"'") | .id' 2>/dev/null || true)
  if [ -n "$RUN_ID" ]; then break; fi
  sleep 10
done

if [ -z "$RUN_ID" ]; then
  echo "ERROR: Could not find CI run for $SHA"
  exit 1
fi

echo "Found run $RUN_ID, waiting for completion..."

# Poll until complete
while true; do
  STATUS=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq '.status' 2>/dev/null)
  if [ "$STATUS" = "completed" ]; then break; fi
  sleep 30
done

CONCLUSION=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq '.conclusion')
echo "Run completed: $CONCLUSION"

if [ "$CONCLUSION" != "success" ]; then
  echo "METRIC wall_clock_min=999"
  echo "CI run failed ($CONCLUSION)"
  exit 1
fi

# Analyze job timings
(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100&page=1" --jq '.jobs[] | "\(.name)\t\(.started_at)\t\(.completed_at)"'
gh api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100&page=2" --jq '.jobs[] | "\(.name)\t\(.started_at)\t\(.completed_at)"') > /tmp/autoresearch_jobs.tsv 2>&1

python3 -c "
from datetime import datetime
jobs = []
with open('/tmp/autoresearch_jobs.tsv') as f:
    for line in f:
        parts = line.strip().split(chr(9))
        if len(parts) != 3: continue
        name, start, end_ = parts
        if 'null' in start or 'null' in end_: continue
        s = datetime.fromisoformat(start.replace('Z','+00:00'))
        e = datetime.fromisoformat(end_.replace('Z','+00:00'))
        dur = (e - s).total_seconds()
        jobs.append((name, dur, s, e))

fast = [(n,d) for n,d,_,_ in jobs if 'Fast' in n and d > 10]
slow = [(n,d) for n,d,_,_ in jobs if 'Slow' in n and d > 10]
build = [(n,d) for n,d,_,_ in jobs if 'Build' in n or 'build' in n.lower()]

fast.sort(key=lambda x: -x[1])
slow.sort(key=lambda x: -x[1])

all_starts = [s for _,_,s,_ in jobs if s]
all_ends = [e for _,_,_,e in jobs if e]
wall = (max(all_ends) - min(all_starts)).total_seconds() / 60 if all_starts and all_ends else 999

build_total = sum(d for _,d in build if d > 1) / 60
fast_longest = fast[0][1] / 60 if fast else 0
slow_longest = slow[0][1] / 60 if slow else 0
runner_total = sum(d for _,d,_,_ in jobs) / 60

print(f'METRIC wall_clock_min={wall:.1f}')
print(f'METRIC build_min={build_total:.1f}')
print(f'METRIC fast_longest_min={fast_longest:.1f}')
print(f'METRIC slow_longest_min={slow_longest:.1f}')
print(f'METRIC runner_minutes_total={runner_total:.0f}')
print(f'Fast nodes: {len(fast)}, Slow nodes: {len(slow)}')
print(f'Wall clock: {wall:.1f}min, Build: {build_total:.1f}min')
print(f'Fast longest: {fast_longest:.1f}min, Slow longest: {slow_longest:.1f}min')
"
