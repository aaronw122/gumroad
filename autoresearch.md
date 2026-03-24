# Autoresearch: Fix flaky Dropbox test — 5 consecutive green CI runs

## Metrics
- **Primary**: consecutive_greens (unitless, higher is better)

## How to Run
`autoresearch.sh` — should emit `METRIC name=number` lines for consecutive_greens.

## What's Been Tried
- #1 baseline keep 1 6f47c49 — First CI run with fix: batch ID mappings in save_files! to prevent transitive collision
- #2 crash 1 7179dd2 — CI infra failure: git checkout failed due to .claude/worktrees submodule path in .gitmodules. Not a test failure.
- #3 crash 1 7179dd2 — Same CI infra failure on rerun — .claude/worktrees tracked as git submodules breaks checkout

## Plugin Checkpoint
- Last updated: 2026-03-24T21:10:32.609Z
- Runs tracked: 3 current / 3 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #3 crash 7179dd2 — Same CI infra failure on rerun — .claude/worktrees tracked as git submodules breaks checkout
- Pending run awaiting log_experiment: cd /Users/gumclaw/.openclaw/workspace/repos/gumroad && gh run watch 23511684369 --exit-status 2>&1; echo "EXIT_CODE=$?" (n/a)

Z
- Runs tracked: 3 current / 3 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #3 crash 7179dd2 — Same CI infra failure on rerun — .claude/worktrees tracked as git submodules breaks checkout

Z
- Runs tracked: 2 current / 2 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #2 crash 7179dd2 — CI infra failure: git checkout failed due to .claude/worktrees submodule path in .gitmodules. Not a test failure.
- Pending run awaiting log_experiment: cd /Users/gumclaw/.openclaw/workspace/repos/gumroad && gh run watch 23511594343 --exit-status 2>&1; echo "EXIT_CODE=$?" (n/a)

Z
- Runs tracked: 2 current / 2 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #2 crash 7179dd2 — CI infra failure: git checkout failed due to .claude/worktrees submodule path in .gitmodules. Not a test failure.

Z
- Runs tracked: 1 current / 1 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #1 keep 6f47c49 — First CI run with fix: batch ID mappings in save_files! to prevent transitive collision
- Pending run awaiting log_experiment: cd /Users/gumclaw/.openclaw/workspace/repos/gumroad && gh run watch 23511594343 --exit-status 2>&1; echo "EXIT_CODE=$?" (n/a)

Z
- Runs tracked: 1 current / 1 total
- Baseline: 1
- Best kept: 1
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Last logged run: #1 keep 6f47c49 — First CI run with fix: batch ID mappings in save_files! to prevent transitive collision

Z
- Runs tracked: 0 current / 0 total
- Baseline: n/a
- Best kept: n/a
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
- Pending run awaiting log_experiment: cd /Users/gumclaw/.openclaw/workspace/repos/gumroad && gh run watch 23510795802 --exit-status 2>&1; echo "EXIT_CODE=$?" (n/a)

Z
- Runs tracked: 0 current / 0 total
- Baseline: n/a
- Best kept: n/a
- Confidence: n/a
- Canonical branch: fix/flaky-dropbox-test
