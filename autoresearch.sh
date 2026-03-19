#!/usr/bin/env bash
set -euo pipefail

# Push current branch to trigger CI, watch the run, report results
BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse --short HEAD)

echo "=== Pushing $BRANCH ($SHA) to trigger CI ==="
git push origin "$BRANCH" --force-with-lease 2>&1 || git push origin "$BRANCH" --force 2>&1

# Wait for the run to appear
echo "=== Waiting for CI run to start ==="
sleep 15

# Find the latest Tests run for this branch
RUN_ID=""
for i in {1..12}; do
  RUN_ID=$(gh run list --branch "$BRANCH" --limit 5 --json databaseId,name,headSha,status | \
    jq -r "[.[] | select(.name == \"Tests\" and .status != \"completed\")] | .[0].databaseId // empty")
  if [ -n "$RUN_ID" ]; then
    break
  fi
  # Also check just-completed runs
  RUN_ID=$(gh run list --branch "$BRANCH" --limit 3 --json databaseId,name,headSha,createdAt | \
    jq -r "[.[] | select(.name == \"Tests\")] | .[0].databaseId // empty")
  if [ -n "$RUN_ID" ]; then
    break
  fi
  echo "  Waiting for run to appear (attempt $i/12)..."
  sleep 10
done

if [ -z "$RUN_ID" ]; then
  echo "ERROR: Could not find CI run after 2 minutes"
  exit 1
fi

echo "=== Watching run $RUN_ID ==="
gh run watch "$RUN_ID" --exit-status 2>&1 || true

# Collect results
CONCLUSION=$(gh run view "$RUN_ID" --json conclusion -q .conclusion)
FAILED_JOBS=$(gh run view "$RUN_ID" --json jobs | jq '[.jobs[] | select(.conclusion == "failure")] | length')
TOTAL_JOBS=$(gh run view "$RUN_ID" --json jobs | jq '[.jobs[] | select(.name | startswith("Test"))] | length')
PASSED_JOBS=$((TOTAL_JOBS - FAILED_JOBS))

# Count individual test failures from failed job logs
TOTAL_FAILURES=0
if [ "$FAILED_JOBS" -gt 0 ]; then
  TOTAL_FAILURES=$(gh run view "$RUN_ID" --log-failed 2>&1 | grep -c '##\[error\]' || echo 0)
  # Subtract "Process completed with exit code 1" lines
  PROCESS_EXITS=$(gh run view "$RUN_ID" --log-failed 2>&1 | grep -c 'Process completed with exit code' || echo 0)
  TOTAL_FAILURES=$((TOTAL_FAILURES - PROCESS_EXITS))
fi

echo ""
echo "=== RESULTS ==="
echo "Run ID: $RUN_ID"
echo "Conclusion: $CONCLUSION"
echo "Total test jobs: $TOTAL_JOBS"
echo "Passed: $PASSED_JOBS"
echo "Failed: $FAILED_JOBS"
echo "Individual test failures: $TOTAL_FAILURES"
echo ""
echo "METRIC failed_jobs=$FAILED_JOBS"
echo "METRIC total_failures=$TOTAL_FAILURES"
echo "METRIC passed_jobs=$PASSED_JOBS"
