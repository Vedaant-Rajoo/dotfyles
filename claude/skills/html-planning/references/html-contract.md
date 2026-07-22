# HTML plan contract

## Structured input

`build-plan.mjs` accepts a JSON object with this shape. Unknown fields are ignored.

```json
{
  "title": "Concise plan title",
  "summary": "One-line technical outcome",
  "objective": "Detailed objective",
  "status": "Proposed",
  "scope": "Small | Medium | Large",
  "risk": "Low | Medium | High",
  "sourceRevision": "optional git revision",
  "successCriteria": [{"text": "Observable criterion", "check": "How to verify"}],
  "requirements": ["Requirement"],
  "nonGoals": ["Boundary"],
  "currentImplementation": ["Verified fact with path:line where possible"],
  "design": [{"heading": "Area", "body": "Recommendation and rationale"}],
  "files": [{"path": "src/file.ts:42", "change": "Expected change", "reason": "Why here"}],
  "phases": [{"title": "Phase", "prerequisite": "Dependency", "deliverable": "Outcome", "steps": ["Step"], "verification": ["Check"]}],
  "failureHandling": ["Failure and recovery behavior"],
  "verification": ["End-to-end check"],
  "rollout": ["Rollout or rollback step"],
  "risks": [{"risk": "Risk", "impact": "Impact", "mitigation": "Mitigation"}],
  "assumptions": ["Explicit assumption"],
  "openDecisions": [{"question": "Decision", "why": "Why it matters", "needed": "Evidence or user choice"}]
}
```

## Rendering contract

- Produce one complete static HTML document with inline CSS and no JavaScript.
- Pre-render every visible section; the document must not depend on runtime code.
- Embed the sanitized canonical object in `<template id="plan-data">` for local validation and collision checks.
- Escape ampersand, less-than, and greater-than characters in embedded JSON with Unicode escapes so the data cannot create markup or terminate the template.
- Include only substantive sections; do not emit empty cards or tabs.
- Use semantic headings, landmarks, tables, lists, and `details` elements.
- Support keyboard navigation, visible focus, light/dark mode, reduced motion, narrow screens, and browser-native printing.
- Use system fonts and no remote assets, network links, forms, frames, embeds, or scripts.
- Keep the UTF-8 document within Postplan's default 512 KiB upload limit.

## Output naming

Use a concise kebab-case slug derived from the objective. If the target exists and contains the same normalized title, replace it atomically. If it belongs to a different plan, append the first eight characters of a content hash.

Store the canonical artifact at `<project>/.claude/plans/<slug>.html`. Do not retain an unsanitized sibling file.
