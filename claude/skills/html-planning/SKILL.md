---
name: html-planning
description: Use when the user asks to plan technical work — "plan this feature", "design the implementation", "create a technical plan", "break down this refactor", "plan the migration/rollout/integration", "investigate and propose changes", "how should we build this". Builds a standalone static HTML plan page in the project's .claude/plans directory, then publishes it to a public Postplan URL for reference. Not for pricing plans, travel plans, or questions that merely contain the word "plan".
user-invocable: true
---

# HTML Planning

One job: turn a technical planning request into a plan page a reviewer can decide on in under a minute — what changes, what is blocked on them, and how anyone will know it worked.

## Workflow

1. **Gather evidence.** Resolve the project root (`git rev-parse --show-toplevel`, else cwd). Read the code paths the request touches, analogous features, and tests. Never invent files, APIs, owners, or estimates the repo does not support.
2. **Write the plan JSON** to `<project>/.claude/plans/plan.json` following the contract below. `example.plan.json` in this skill directory is a full-coverage sample.
3. **Build:** `node "$CLAUDE_SKILL_DIR/build.mjs" <project>/.claude/plans/plan.json`
   The script assigns the next plan number, renames the JSON to `<NNN>-<slug>.json`, writes `<NNN>-<slug>.html` beside it, and prints the HTML path.
4. **Publish:** `postplan upload <NNN>-<slug>.html --description "<title>"`
   The CLI's own draft mapping (`~/.postplan/drafts.json`) makes the first upload create a draft and every re-upload of the same path update the same draft/URL. Never pass `--new`.
5. **Report** the local HTML path and the public Postplan URL, then `open` the URL.

If the upload fails (offline, auth expired — check `postplan whoami`), still deliver the local page: report the `file://` path and the exact retry command. Never block plan delivery on publishing; never use another host.

## Revising a plan

Edit the existing `<NNN>-<slug>.json`, increment `rev`, rebuild, re-upload. The same HTML file is overwritten and the same URL updates — the number is the identity, the rev is the history, git is the archive. Never create a second file for a revision.

## plan.json contract

Required: `title`, `intent`, `project`, `questions[]` (may be empty), `approach{thesis, rationale, dropped[{what, why}]}`, `steps[]`, `tests[{kind: auto|manual, condition, expected}]`, `doneWhen[]`.
Optional: `branch`, `rev` (default 1), `status` (`awaiting review` · `blocked` · `approved` · `in progress` · `draft` · `superseded`), `risks[{risk, mitigation}]`, `notInScope[]`, `effort[{label, share, fill: accent|hatch|light|inert}]`, `callout` (one per plan), `layout` (`dossier`|`ledger`, overrides auto-pick).

- Each question: `{q, consequence, options[]?, default, blocksStep?}` — `default` is mandatory.
- Each step: `{title, rationale, files[{action: new|edit|del, path}], verify, diff?: "+N −M", blockedOn?: "Q1"}` — at least one file and a verify line are mandatory.
- `planNumber` is assigned by the script on first build; its presence makes the next build a revision.
- Counters, numbering, and dates are computed by the script — never write them by hand.
- No HTML in any JSON value; every string is escaped by the renderer. Summarize evidence, don't paste code or logs.

Layout auto-pick: **ledger** when steps > 6 or files > 12, else **dossier**. The effort bar renders only when `effort[]` is present and steps > 6.

## Content rules (from the design system)

1. **Blocked-on-you goes first.** The reader is looking for their homework, not your reasoning.
2. **Every question states its default.** Silence must be safe, so a plan can proceed unattended.
3. **No step without a path and a verification.** Both fit on one line each.
4. **Reasoning is one paragraph, never two.** Dropped alternatives get one ✕ line.
5. **Mono is for machine facts** (paths, commands, counts); sans for human judgment. The renderer handles this — don't fight it in content.
6. **Accent means "a human has to act."** Keep accented elements (open questions, blocked markers) to three or fewer per page — if everything is urgent, nothing is.
7. **Plans get revised, not rewritten.** Bump the rev, keep the number.

Include only substantive sections — empty sections are omitted by the renderer, so leave optional fields out rather than padding them.

## Publishing caveats

- Postplan drafts are **public**: authentication is ownership, not privacy.
- No TTL and no CLI delete — treat published plans as persistent.
- Keep secrets, private hostnames, and pasted internals out of plan content; describe private endpoints by role.
- Postplan's CSP blocks external fonts, so the published copy renders in system fonts; the local file gets IBM Plex. Expected, not a bug.
