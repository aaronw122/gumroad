# Autoresearch: Fix Flaky Tests

## Objective
Reduce flaky test failures in the Gumroad CI suite. Tests run across 15 Fast + 45 Slow shards on Ubicloud runners using Knapsack Pro for distribution. Tests are system/request specs using Capybara + Selenium (Chrome headless).

## Metrics
- **Primary**: failed_jobs (count, lower is better)
- **Secondary**: total_failures (count of individual test failures)

## How to Run
`./autoresearch.sh` — pushes to branch, triggers CI, watches run, counts failed jobs.

## Files in Scope
- `spec/support/product_file_list_helpers.rb` — `wait_for_file_embed_to_finish_uploading` has stale element bug
- `spec/support/checkout_helpers.rb` — checkout flow helpers
- `spec/support/capybara_helpers.rb` — `wait_for_ajax` and other Capybara utilities
- `spec/requests/purchases/product/taxes_spec.rb` — US sales tax test race condition (line ~193)
- `spec/requests/products/edit/rich_text_editor_spec.rb` — audio embed upload test (line ~555)
- `spec/spec_helper.rb` — test configuration, Selenium setup, retry config

## Off Limits
- Application code (app/, lib/, config/) — only test infrastructure
- CI workflow files (.github/workflows/) — no CI config changes
- Other test files not related to identified flaky patterns

## Constraints
- Tests must pass (we're fixing flakiness, not breaking tests)
- No new gem dependencies
- Fixes must be general (not test-specific hacks)
- Each experiment = push to branch → full CI run → observe results
- Use `gh run watch --exit-status` to monitor

## Known Flaky Patterns (from CI analysis)

### Pattern 1: Tax calculation race condition
- `taxes_spec.rb:193` — `set_zip_code_via_js("53703")` → `wait_for_ajax` → `expect(page).to have_text("Total US$105.50")`
- `wait_for_ajax` checks jQuery.active === 0, but React state updates + API calls may not be tracked by jQuery
- Page shows "Total US$100" (no tax) because the tax recalculation hasn't completed
- Fix: Replace `wait_for_ajax` + expect with direct `have_text` assertion (Capybara auto-waits)

### Pattern 2: Stale element in file embed upload
- `rich_text_editor_spec.rb:555` calls `wait_for_file_embed_to_finish_uploading`
- `find_embed` finds element, then `page.scroll_to row` fails with StaleElementReferenceError
- React re-renders the embed component during upload progress updates
- Fix: Re-find element after scroll or wrap in retry

### Pattern 3: Selenium session corruption from Stripe rate limits
- Stripe rate limits kill tests mid-execution, browser session becomes corrupt
- Subsequent tests fail with `NoMethodError: undefined method 'unpack1' for false`
- Then cascade: `NoSuchWindowError`, `undefined method 'slice' for nil`, etc.
- All remaining tests in shard fail (30+ failures from one root cause)
- Fix: Better Selenium session recovery in spec_helper after_each hooks

## What's Been Tried
(Will be updated as experiments run)
