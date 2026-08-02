# Homebrew Cask Application Lifecycle Design

> **Superseded 2026-08-01.** A simplification review replaced the durable
> on-disk lifecycle state this design specifies (TSV stores, atomic pending
> publication, signal fences, reopen-fallback queue) with in-memory fish lists
> (commit cb305c2). The behavior contract — consolidated confirmation,
> graceful-then-force stop, pre-upgrade recheck, immediate reopen, skip/failure
> reporting — still holds and remains tested.

## Summary

Enhance `bin/u` so Homebrew cask upgrades do not leave already-running applications executing the old version after Homebrew replaces their bundles. The update workflow will identify outdated casks with `.app` artifacts, determine which corresponding applications are running, close only those applications, upgrade their casks, and reopen the applications that were running before the upgrade.

Lifecycle handling applies only to casks with `.app` artifacts. Formulae, fonts, command-line casks, plugins, and installer-only casks retain normal Homebrew behavior.

## Goals

- Discover affected applications from Homebrew and macOS metadata without maintaining a manual cask-to-process map.
- Show one consolidated confirmation before closing running applications.
- Request graceful termination first.
- Ask before force-terminating any application that does not quit within a bounded interval.
- Skip a cask when one of its running applications cannot be stopped safely.
- Reopen every application the workflow closed, even when its cask upgrade fails or the workflow exits early.
- Isolate cask failures so unrelated casks can still upgrade.
- Preserve clear timestamped logs and return a nonzero status when attempted work fails.

## Non-goals

- Managing the lifecycle of formulae or non-app casks.
- Guessing application identity from cask tokens, display names, or broad process-name matches.
- Maintaining a registry for individual applications before a demonstrated exception requires one.
- Force-upgrading applications that the user declined to close.
- Reinstalling or downgrading casks solely to test the automation.

## Architecture

### `bin/u`

`bin/u` remains the top-level maintenance coordinator. It owns:

- user prompts;
- Homebrew discovery and upgrade commands;
- classification of formulae and casks;
- per-cask eligibility decisions;
- logging and summaries;
- aggregate exit status;
- cleanup coordination.

The Homebrew section is divided into explicit formula and cask phases rather than one undifferentiated `brew upgrade` call.

### macOS application lifecycle helper

A focused helper script owns macOS application inspection and lifecycle operations. It uses `osascript -l JavaScript` with AppKit and `NSWorkspace`, providing a narrow command-oriented interface for:

- reading an app bundle's path and bundle identifier;
- listing matching running application instances;
- requesting normal termination;
- checking whether matching instances remain active;
- force-terminating exact matched instances after approval;
- reopening an application from its recorded bundle path.

Matching uses bundle identifiers and resolved bundle URLs. A recorded process ID may be used only as a narrow fallback. The implementation must not use broad `pkill -f` or guessed process-name matching.

The helper returns machine-readable output so `bin/u` does not parse human-oriented AppleScript text.

## Homebrew discovery

After `brew update`, `bin/u` obtains structured outdated-package data with `brew outdated --json=v2`. Formula and cask records are handled separately.

For each outdated cask, `brew info --cask --json=v2 <token>` supplies artifact metadata. Only `app` artifacts participate in lifecycle handling. Other artifacts do not trigger process inspection.

A cask can contain zero, one, or multiple `.app` artifacts. The workflow records for each app artifact:

- cask token;
- installed bundle path;
- bundle identifier;
- whether it was running before any termination request;
- matching running instances needed for exact termination.

## Upgrade flow

1. Run `brew update`.
2. Discover outdated formulae and casks using Homebrew JSON output.
3. Upgrade outdated formulae as a formula-only operation.
4. Inspect every outdated cask and classify it as:
   - no `.app` artifact;
   - app cask with no running application;
   - app cask with at least one running application.
5. Display one consolidated list of running applications whose casks are outdated.
6. Ask once for permission to close the listed applications.
7. If permission is declined, skip only casks containing those running applications. Continue with non-running app casks and non-app casks.
8. For approved applications, request graceful termination.
9. Wait up to 10 seconds for each application to terminate normally.
10. If an application remains active, ask before force-terminating its exact matched instances.
11. If force termination is declined or unsuccessful, mark the entire owning cask ineligible and skip its upgrade.
12. Upgrade each eligible cask independently with `brew upgrade --cask <token>`.
13. Immediately after each cask attempt, reopen every app artifact from that cask that was running before the workflow closed it.
14. Continue processing later casks when an individual cask upgrade fails.
15. Run Homebrew cleanup and doctor after upgrade processing, subject to the aggregate failure policy.
16. Print a final summary and return a nonzero status if any attempted upgrade or required lifecycle operation failed.

## Multi-app casks

A cask with multiple `.app` artifacts is eligible only when every initially running artifact has stopped successfully. If any running artifact cannot be stopped, the complete cask upgrade is skipped to avoid replacing only part of an active cask installation.

Only artifacts that were running before lifecycle handling are reopened. Applications that were initially closed remain closed.

## Failure and cleanup behavior

### Formula failure

A formula upgrade failure remains fatal before cask processing, preserving the current fail-fast behavior for the formula phase.

### Cask failure

Casks are upgraded individually. A failed cask:

- is logged as failed;
- has its previously running applications reopened immediately;
- does not prevent subsequent casks from being attempted;
- contributes to the final nonzero exit status.

### Lifecycle failure

If an application cannot be identified reliably, cannot be stopped, or the user declines required force termination, its cask is skipped. The reason is logged and included in the final summary.

A user-declined close or force-termination prompt is a deliberate skip, not an upgrade-command failure. It is reported clearly without pretending the cask was upgraded.

### Exit cleanup

`bin/u` tracks each application it successfully closes. An idempotent cleanup handler attempts to reopen any tracked application not already reopened. The handler runs on normal completion, command failure, early exit, and handled interruption signals.

An application is removed from cleanup tracking only after a successful reopen attempt. Reopen failures are logged and contribute to the final nonzero status. Repeated cleanup execution must not launch duplicate application instances.

## Logging and user interaction

The existing `/tmp/u-<timestamp>.txt` log remains the source of truth. New entries include:

- outdated formula and cask tokens;
- discovered `.app` artifacts;
- initially running applications;
- consolidated close-confirmation result;
- graceful termination attempts and timeouts;
- approved or declined force termination;
- skipped casks and reasons;
- each cask upgrade result;
- reopen attempts and results;
- final counts for upgraded, skipped, and failed casks.

Interactive Homebrew output continues streaming through `tee` so password prompts remain visible and the actual Homebrew exit status is preserved from Fish's pipeline status.

## Verification strategy

The repository does not currently provide a shell-test framework. The implementation will keep discovery, classification, and decision logic in small Fish functions and make external commands replaceable through `PATH` so deterministic fixture commands can exercise the workflow without modifying installed casks.

Automated verification covers:

- `fish --no-execute` syntax validation;
- Homebrew JSON with formulae, app casks, non-app casks, and multiple app artifacts;
- no outdated packages;
- running and non-running applications;
- declined consolidated close confirmation;
- successful graceful termination;
- graceful timeout followed by accepted force termination;
- graceful timeout followed by declined force termination;
- skipped multi-app cask when one running artifact cannot stop;
- cask upgrade failure followed by reopening;
- continued processing after one cask fails;
- cleanup reopening applications after early exit or interruption;
- no reopening of applications that were initially closed;
- nonzero final status for attempted-upgrade or required-reopen failures.

A final macOS smoke test uses an already-installed, harmless Homebrew-managed application. It opens the app and verifies that a non-upgrading inspection or dry-run path identifies only the intended bundle. It does not force a reinstall, downgrade, or destructive update.

## Success criteria

- Running applications upgraded through Homebrew casks no longer remain on the pre-upgrade in-memory version.
- No application is force-terminated without a dedicated confirmation.
- No unrelated process is targeted through guessed names or broad pattern matching.
- Every application closed by the workflow is reopened after its cask attempt, including failed attempts.
- Formula and non-app cask behavior remains free of application lifecycle handling.
- Logs distinguish upgraded, skipped, and failed casks accurately.
