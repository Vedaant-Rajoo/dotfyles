# Shared agent instructions

This file is the platform-neutral source of truth for AI coding harnesses on this
machine. Harness-specific files may add native behavior, but must not contradict
these instructions.

## Planning

When asked to plan technical work — implementation, architecture, migration,
refactor, rollout, integration, or investigation — use the `html-planning`
skill and deliver its HTML plan page. If the active harness cannot invoke skills
directly, locate and follow `agents/skills/html-planning/SKILL.md`. Do not use it
for non-technical plans (pricing, travel, scheduling) or questions that merely
contain the word plan.

## Conformance canary

When the user's entire prompt is exactly `CANARY-CHECK`, reply with exactly
`AGENTS-OK 1` and nothing else. This rule exists only so `bin/agents_conform
--live` can verify that a harness loaded this file.
