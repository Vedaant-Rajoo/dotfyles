# Homebrew Cask Application Lifecycle Implementation Plan

> **Superseded 2026-08-01.** The durable state machinery this plan builds was
> replaced by an in-memory rewrite of `bin/u` (commit cb305c2). Kept for the
> design history.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `bin/u` close running applications before their Homebrew casks upgrade and reliably reopen only the applications that were running initially.

**Architecture:** Refactor `bin/u` into sourceable Fish functions with a guarded `u_main`, then add structured Homebrew discovery, per-cask orchestration, and idempotent cleanup. A focused JXA helper uses AppKit `NSWorkspace` and `NSRunningApplication` for bundle- and PID-specific lifecycle operations; a Fish test harness replaces external commands through `PATH` and fixtures.

**Tech Stack:** Fish 4.x, Homebrew JSON v2, `jq`, JavaScript for Automation through `/usr/bin/osascript`, AppKit, macOS `open`, Git.

## Global Constraints

- Lifecycle handling applies only to outdated casks with `.app` artifacts.
- Show one consolidated confirmation before closing running applications.
- Wait at most 10 seconds for graceful termination, then ask before force termination.
- Never use broad `pkill -f` or guessed process-name matching.
- Skip the complete cask if any initially running artifact cannot be stopped.
- Always attempt to reopen applications closed by the workflow, including after upgrade failure or interruption.
- Formula upgrades remain fail-fast; cask failures are isolated and aggregated into the final status.
- Preserve visible Homebrew and sudo prompts while recording output in `/tmp/u-<timestamp>.txt`.
- Do not include or overwrite the unrelated `nvim/lazy-lock.json` working-tree change.

---

## File Structure

- **Modify:** `bin/u` — top-level Fish coordinator, Homebrew JSON parsing, prompts, lifecycle state, per-cask upgrades, logging, cleanup, and aggregate status.
- **Create:** `bin/u-cask-lifecycle.js` — JXA/AppKit adapter for inspecting bundles and operating on exact bundle-ID/PID pairs.
- **Create:** `tests/bin/u_test.fish` — dependency-free Fish test runner for pure functions and end-to-end orchestration with mocked commands.
- **Create:** `tests/bin/u-cask-lifecycle_test.fish` — helper contract, argument validation, compilation, safe metadata inspection, and nonexistent-PID checks.

## Defined Interfaces

### Fish coordinator

```fish
function u_main
function u_discover_outdated --argument-names json
function u_cask_app_paths --argument-names cask_json
function u_inspect_app --argument-names bundle_path
function u_prepare_cask --argument-names token
function u_stop_cask_apps --argument-names token
function u_upgrade_cask --argument-names token
function u_reopen_token_apps --argument-names token
function u_cleanup
function u_record_failure --argument-names category subject detail
```

`u_discover_outdated` writes normalized tab-separated records to `$U_STATE_DIR/formulae.tsv` and `$U_STATE_DIR/casks.tsv`. Application state is stored in `$U_STATE_DIR/apps.tsv` with columns `token`, `path`, `bundle_id`, `pids_csv`, `was_running`, `closed`, and `reopened`. Failures and skips are written to separate TSV files for the summary.

### JXA helper

```text
osascript -l JavaScript bin/u-cask-lifecycle.js inspect <bundle-path>
osascript -l JavaScript bin/u-cask-lifecycle.js running <bundle-id> [pid ...]
osascript -l JavaScript bin/u-cask-lifecycle.js terminate <bundle-id> [pid ...]
osascript -l JavaScript bin/u-cask-lifecycle.js force-terminate <bundle-id> [pid ...]
```

All successful commands emit one JSON object. `inspect` emits `{"path":string,"bundleId":string,"pids":number[]}`. The PID commands emit `{"bundleId":string,"pids":number[]}` where `pids` contains instances that matched the supplied bundle identifier and were still available for the requested operation. Usage errors exit 64; unreadable or invalid bundles exit 66; lifecycle API failures exit 70.

---

### Task 1: Make `bin/u` sourceable and establish the Fish test harness

**Files:**
- Modify: `bin/u:1-64`
- Create: `tests/bin/u_test.fish`

**Interfaces:**
- Produces: guarded `u_main`; `U_TEST_MODE=1` sources functions without running maintenance; test-local assertion and mock helpers.

- [ ] **Step 1: Write the failing sourceability test**

Add a test that invokes:

```fish
set -lx U_TEST_MODE 1
source "$repo_root/bin/u"
assert_function u_main
```

The test runner must print `not ok - source exposes u_main` and exit nonzero before the refactor.

- [ ] **Step 2: Run the test and verify failure**

Run: `fish tests/bin/u_test.fish`

Expected: nonzero exit because sourcing the current script executes UI and does not define `u_main`.

- [ ] **Step 3: Wrap current behavior in focused functions**

Move the existing top-level sequence into `u_main`; add `u_log`, `u_run_logged`, and `u_run_brew_upgrade`; retain the existing command order and pipeline-status handling. End the file with:

```fish
if not set -q U_TEST_MODE
    u_main $argv
end
```

No cask lifecycle behavior is added in this task.

- [ ] **Step 4: Run syntax and regression tests**

Run:

```bash
fish --no-execute bin/u
fish tests/bin/u_test.fish
```

Expected: both pass; the test confirms `u_main` is defined and top-level commands are not executed in test mode.

- [ ] **Step 5: Commit**

```bash
git add bin/u tests/bin/u_test.fish
git commit -m "refactor(bin): make update workflow testable" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 2: Parse Homebrew JSON and classify cask artifacts

**Files:**
- Modify: `bin/u`
- Modify: `tests/bin/u_test.fish`

**Interfaces:**
- Produces: `u_discover_outdated <json>` and `u_cask_app_paths <cask-json>` using the TSV contracts above.
- Consumes: `jq`; `$U_STATE_DIR` created by `u_main` or the test harness.

- [ ] **Step 1: Add failing JSON fixture tests**

Cover empty JSON, one formula, an app cask, a non-app cask, and a cask with two app artifacts. Use inline fixture strings and assert exact normalized output, including the Homebrew `target` path:

```json
{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}
```

```json
{"casks":[{"token":"cursor","artifacts":[{"app":["Cursor.app"],"target":"/Applications/Cursor.app"},{"binary":["cursor"]}]}]}
```

- [ ] **Step 2: Run tests and verify the new assertions fail**

Run: `fish tests/bin/u_test.fish`

Expected: nonzero exit because the discovery functions do not exist.

- [ ] **Step 3: Implement minimal structured parsing**

Use `jq -r` only against JSON v2 fields. `u_discover_outdated` writes formula `.name` and cask `.name` values. `u_cask_app_paths` emits only `.artifacts[] | select(.app) | .target`, rejecting missing or non-absolute targets as a lifecycle inspection failure rather than guessing `/Applications`.

- [ ] **Step 4: Run tests and inspect a real cask schema**

Run:

```bash
fish tests/bin/u_test.fish
brew info --cask --json=v2 cursor | jq '.casks[0].artifacts'
```

Expected: tests pass; Cursor's app artifact includes `/Applications/Cursor.app` as `target`.

- [ ] **Step 5: Commit**

```bash
git add bin/u tests/bin/u_test.fish
git commit -m "feat(bin): classify outdated Homebrew casks" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 3: Implement the bundle- and PID-specific JXA lifecycle helper

**Files:**
- Create: `bin/u-cask-lifecycle.js`
- Create: `tests/bin/u-cask-lifecycle_test.fish`

**Interfaces:**
- Produces: the four JXA commands and JSON/exit-code contract defined above.
- Consumes: AppKit `NSWorkspace.sharedWorkspace.runningApplications` and `NSRunningApplication` methods.

- [ ] **Step 1: Write failing helper contract tests**

Test:

- missing command exits 64;
- unknown command exits 64;
- nonexistent bundle exits 66;
- `inspect /System/Applications/Calculator.app` emits a nonempty `bundleId` and numeric `pids` array;
- `running com.example.missing 2147483647` emits an empty array;
- the script compiles with `osacompile -l JavaScript`.

- [ ] **Step 2: Run helper tests and verify failure**

Run: `fish tests/bin/u-cask-lifecycle_test.fish`

Expected: nonzero exit because `bin/u-cask-lifecycle.js` does not exist.

- [ ] **Step 3: Implement argument parsing and bundle inspection**

Import AppKit and Foundation. Resolve bundle paths with `NSURL.fileURLWithPath(...).URLByResolvingSymlinksInPath`, load `NSBundle`, require a bundle identifier, and match running applications by both bundle identifier and resolved bundle URL when the running URL is available.

- [ ] **Step 4: Implement exact PID operations**

For each supplied PID, fetch `NSRunningApplication.runningApplicationWithProcessIdentifier`, verify its bundle identifier equals the supplied identifier, then call `terminate` or `forceTerminate`. `running` reports only still-live matching PIDs. Never search by executable name or partial command line.

- [ ] **Step 5: Run helper tests**

Run:

```bash
fish tests/bin/u-cask-lifecycle_test.fish
```

Expected: all contract tests pass without quitting any real application.

- [ ] **Step 6: Commit**

```bash
git add bin/u-cask-lifecycle.js tests/bin/u-cask-lifecycle_test.fish
git commit -m "feat(bin): add macOS cask lifecycle helper" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 4: Discover running cask apps and request consolidated approval

**Files:**
- Modify: `bin/u`
- Modify: `tests/bin/u_test.fish`

**Interfaces:**
- Produces: `u_inspect_app`, `u_prepare_cask`, and a consolidated `u_confirm_running_apps` decision.
- Consumes: `bin/u-cask-lifecycle.js inspect`, `brew info --cask --json=v2`, and application-state TSV columns.

- [ ] **Step 1: Add failing orchestration tests with mocked commands**

Put temporary `brew`, `osascript`, and `gum` executables first in `PATH`. Test that:

- only app artifacts invoke `inspect`;
- non-running app casks remain eligible;
- running apps appear once in one consolidated prompt;
- declining the prompt marks only running-app casks skipped;
- non-app and non-running app casks remain eligible.

- [ ] **Step 2: Run tests and verify failure**

Run: `fish tests/bin/u_test.fish`

Expected: new lifecycle discovery assertions fail.

- [ ] **Step 3: Implement preparation and consolidated confirmation**

`u_prepare_cask` fetches cask JSON, extracts every app target, invokes `inspect`, and appends normalized state. After all casks are prepared, print bundle display names and cask tokens once, then call one `gum confirm`. A declined confirmation records deliberate skips without recording command failures.

- [ ] **Step 4: Run tests**

Run: `fish tests/bin/u_test.fish`

Expected: all discovery and confirmation cases pass; mocks record exactly one consolidated confirmation.

- [ ] **Step 5: Commit**

```bash
git add bin/u tests/bin/u_test.fish
git commit -m "feat(bin): detect running outdated cask apps" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 5: Stop, force-confirm, and idempotently reopen applications

**Files:**
- Modify: `bin/u`
- Modify: `tests/bin/u_test.fish`

**Interfaces:**
- Produces: `u_stop_cask_apps`, `u_reopen_token_apps`, and idempotent `u_cleanup`.
- Consumes: helper `terminate`, `running`, and `force-terminate`; exact state rows from Task 4; `open <bundle-path>`.

- [ ] **Step 1: Add failing lifecycle state-machine tests**

Use mocked helper responses to cover:

- graceful termination succeeds before timeout;
- polling lasts no more than 10 one-second checks;
- a still-running app triggers a dedicated force confirmation;
- accepted force termination makes the cask eligible;
- declined or failed force termination skips the complete cask;
- one failed artifact skips a multi-app cask;
- only initially running apps are reopened;
- cleanup called twice does not reopen an already reopened app twice;
- cleanup after simulated early exit reopens every closed tracked app.

- [ ] **Step 2: Run tests and verify failure**

Run: `fish tests/bin/u_test.fish`

Expected: new stop/reopen assertions fail.

- [ ] **Step 3: Implement graceful and forced termination**

Call `terminate` for exact recorded PIDs, poll `running` once per second for at most 10 seconds, and ask `gum confirm` before `force-terminate`. Update the state row only after confirmed lifecycle outcomes. If any running artifact remains, record a cask skip and do not upgrade that token.

- [ ] **Step 4: Implement reopen tracking and exit handlers**

Install Fish handlers for `fish_exit`, `SIGINT`, and `SIGTERM` that call `u_cleanup`. `u_reopen_token_apps` uses `open <recorded-path>` and marks success atomically. The cleanup function checks state before opening so normal cleanup plus signal cleanup cannot duplicate launches.

- [ ] **Step 5: Run tests**

Run:

```bash
fish --no-execute bin/u
fish tests/bin/u_test.fish
```

Expected: syntax and all lifecycle state-machine tests pass.

- [ ] **Step 6: Commit**

```bash
git add bin/u tests/bin/u_test.fish
git commit -m "feat(bin): manage cask application lifecycles" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 6: Integrate formula and per-cask upgrades with aggregate reporting

**Files:**
- Modify: `bin/u`
- Modify: `tests/bin/u_test.fish`

**Interfaces:**
- Produces: complete `u_main`, `u_upgrade_cask`, `u_record_failure`, final summary and status.
- Consumes: all discovery and lifecycle interfaces from Tasks 2–5.

- [ ] **Step 1: Add failing end-to-end mocked tests**

Cover:

- no outdated packages;
- formula-only upgrade uses `brew upgrade --formula <tokens>` and fails fast;
- non-app cask upgrades without lifecycle calls;
- eligible casks upgrade individually via `brew upgrade --cask <token>`;
- one cask failure reopens its app and later casks still run;
- cask failures produce final nonzero status;
- deliberate skips are reported separately;
- `brew cleanup --prune=all` and `brew doctor` still run after cask-level failures;
- pipeline status comes from `brew`, not `tee`.

- [ ] **Step 2: Run tests and verify failure**

Run: `fish tests/bin/u_test.fish`

Expected: end-to-end sequencing and aggregate-status assertions fail.

- [ ] **Step 3: Replace combined `brew upgrade` with explicit phases**

Use one `brew outdated --json=v2` call. Upgrade named formulae in one formula-only command. Prepare all casks, obtain consolidated approval, then stop and upgrade each eligible cask independently. Stream each upgrade through `tee -a "$U_LOG"` and preserve `$pipestatus[1]`.

- [ ] **Step 4: Add summaries and final status**

Log and print counts for upgraded, skipped, and failed casks. Continue cleanup and doctor after cask-level failures, then return nonzero if any cask upgrade, required lifecycle operation, reopen, cleanup, or doctor operation failed. Keep formula failure fail-fast.

- [ ] **Step 5: Run the full automated suite**

Run:

```bash
fish --no-execute bin/u
fish tests/bin/u-cask-lifecycle_test.fish
fish tests/bin/u_test.fish
```

Expected: all commands pass.

- [ ] **Step 6: Commit**

```bash
git add bin/u tests/bin/u_test.fish
git commit -m "feat(bin): upgrade casks with app lifecycle safety" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 7: Perform macOS smoke verification and final review

**Files:**
- Modify only if verification exposes a defect: `bin/u`, `bin/u-cask-lifecycle.js`, `tests/bin/u_test.fish`, `tests/bin/u-cask-lifecycle_test.fish`

**Interfaces:**
- Consumes: completed workflow and tests.
- Produces: verified implementation with no unrelated changes included.

- [ ] **Step 1: Run static and automated verification**

Run:

```bash
fish --no-execute bin/u
fish tests/bin/u-cask-lifecycle_test.fish
fish tests/bin/u_test.fish
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 2: Run a non-mutating real metadata smoke test**

Run:

```bash
osascript -l JavaScript bin/u-cask-lifecycle.js inspect /Applications/Cursor.app | jq -e '.bundleId | length > 0'
brew outdated --json=v2 | jq -e '.formulae and .casks'
```

Expected: both commands exit 0. The helper may report zero or more PIDs depending on whether Cursor is running; it must identify only Cursor's bundle.

- [ ] **Step 3: Review the working diff and status**

Run:

```bash
git diff --stat main...HEAD
git status --short
```

Expected: lifecycle implementation and tests are present; the pre-existing `nvim/lazy-lock.json` modification remains uncommitted and excluded from feature commits.

- [ ] **Step 4: Request code review and address only verified findings**

Invoke `superpowers:requesting-code-review`, apply confirmed corrections, and rerun Step 1 after any edit.

- [ ] **Step 5: Commit verification-driven corrections if needed**

```bash
git add bin/u bin/u-cask-lifecycle.js tests/bin/u_test.fish tests/bin/u-cask-lifecycle_test.fish
git commit -m "fix(bin): harden cask lifecycle upgrades" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

Skip this commit when review produces no code changes.
