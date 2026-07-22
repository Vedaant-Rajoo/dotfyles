---
name: html-planning
description: This skill should be used whenever the user asks to "plan this feature", "design an implementation approach", "create a technical plan", "break down this refactor", "plan the migration", "plan the rollout", "investigate and propose changes", "how should we build this", or otherwise requests planning for technical implementation, architecture, integration, migration, refactoring, rollout, or investigation work. It creates a tailored standalone HTML execution plan, sanitizes it, saves it under the active project's .claude/plans directory, and publishes it automatically as an authenticated public Postplan draft. Do not use it for pricing plans, travel plans, or factual questions that merely contain the word plan.
user-invocable: true
version: 2.0.0
compatibility: Claude Code on macOS; Node.js 20+; authenticated postplan 0.0.4
---

# HTML Planning

Create project-grounded technical plans as standalone, accessible static HTML artifacts. Treat the local sanitized HTML as the canonical deliverable and the Postplan URL as a persistent public copy.

## Workflow

Follow these steps in order.

### 1. Establish scope and project evidence

Resolve the project root using `git rev-parse --show-toplevel` when available; otherwise use the nearest directory containing a recognized project manifest, then fall back to the current working directory.

Read project instructions, architecture documents, manifests, relevant source, analogous implementations, tests, deployment configuration, and current git state. Trace the execution path affected by the request. Never invent files, APIs, owners, dates, estimates, or architecture that the repository does not support.

Ask a question only when the answer materially changes the implementation and cannot be inferred from the code or request. Prefer a recommendation over an option dump.

Read `references/plan-content.md` before drafting.

### 2. Produce structured plan data

Create a temporary JSON input matching `references/html-contract.md`. Separate:

- verified repository facts;
- recommended changes and their rationale;
- assumptions;
- open decisions requiring the user.

Use project-relative `path:line` anchors where verified. Include only sections with substantive content. Optimize for technical execution rather than stakeholder decoration.

The standing behavior is automatic public publication after deterministic sanitization; do not request a second confirmation. Still fail closed when content is unsafe, Postplan authentication is unavailable, or the installed CLI is incompatible.

### 3. Build and retain the HTML

Derive a concise kebab-case slug from the objective. Run:

```bash
node "${CLAUDE_SKILL_DIR}/scripts/build-plan.mjs" \
  --input <plan-json> \
  --project <project-root> \
  --slug <slug>
```

The command writes the canonical sanitized static artifact to `<project>/.claude/plans/<slug>.html` and prints JSON containing its path and redaction summary. Remove the temporary JSON after a successful build if it was created solely for rendering.

Never retain a second unsanitized plan file. Keep the canonical path stable. The publisher uploads a short-lived validated snapshot at a deterministic hidden path and uses `~/.postplan/drafts.json` to preserve draft identity; moving or renaming the canonical file can still create a separate draft.

### 4. Validate and publish

Read `references/security-and-publishing.md`. Publish only through:

```bash
node "${CLAUDE_SKILL_DIR}/scripts/publish-plan.mjs" \
  --file <project>/.claude/plans/<slug>.html \
  --project <project-root>
```

The publisher pins the production API endpoint and one authenticated key, requires Postplan 0.0.4 and successful `postplan whoami`, then revalidates the file and uploads an immutable snapshot. For a first publication it initializes a content-free placeholder and confirms authenticated ownership before sending plan content; the real plan is always an owned draft update. It never uses `--new`, uses `--draft` only with a validated mapping or verified initialization, and emits validated structured JSON.

Do not call Postplan on a file that bypassed this publisher. If validation, authentication, network access, CLI compatibility, or output validation fails, retain the local sanitized HTML, report the specific non-sensitive failure, and do not try another hosting service.

### 5. Respect Postplan lifecycle and metadata behavior

Postplan drafts are public even when authenticated. Authentication establishes ownership; it does not provide privacy.

Postplan 0.0.4 automatically collects Git and CI provenance from the uploaded file's repository and environment, including repository identity, branch, commit SHA and subject, dirty state, and available CI run/actor metadata. The CLI has no suppression option. Do not claim publication metadata is anonymous or content-only.

Postplan 0.0.4 has no draft TTL and no CLI delete command. Do not schedule deletion or promise automatic expiry. Deleting the local file or its `~/.postplan/drafts.json` mapping does not delete the remote draft. Treat the published copy as persistent unless the user separately requests authenticated API deletion.

### 6. Report the deliverables

Return:

- the local HTML path;
- the public Postplan URL and raw URL;
- the draft ID and version;
- whether the upload created or updated the draft;
- redaction categories and counts;
- verification performed and any limitation;
- the persistence and Git/CI metadata disclosure.

Do not replace the HTML deliverable with a Markdown-only plan after this workflow succeeds.

## Plan Mode limitation

Higher-priority Plan Mode restrictions may prohibit writing or publishing. While Plan Mode is active, write the approval plan only to the permitted plan file. After approval and exit from Plan Mode, immediately resume this workflow to render and publish the HTML. Never claim the HTML or URL exists before the corresponding commands succeed.

## Resources

- `references/plan-content.md` — tailoring and required technical substance.
- `references/html-contract.md` — structured input and static rendering contract.
- `references/security-and-publishing.md` — redaction and public-hosting rules.
- `assets/plan-template.html` — standalone static rendering shell.
- `scripts/build-plan.mjs` — sanitize and render a canonical local plan.
- `scripts/sanitize-and-validate.mjs` — shared fail-closed security checks.
- `scripts/publish-plan.mjs` — validated authenticated Postplan publication.
