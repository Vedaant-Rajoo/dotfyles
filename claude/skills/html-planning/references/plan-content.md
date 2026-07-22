# Technical plan content

## Tailoring standard

Ground every recommendation in one of three things: a stated requirement, an observed repository convention, or a documented external constraint. Cite verified code as project-relative `path:line`. Label inferences and do not convert uncertainty into fact.

Before drafting, locate the current execution path, analogous features, tests, configuration, error handling, observability, and rollout conventions. Reuse existing utilities and patterns instead of proposing parallel abstractions.

Do not invent owners, deadlines, effort estimates, filenames, services, APIs, or architectural boundaries. Put unresolved material under **Open decisions** and state what evidence or user choice resolves it.

## Normal plan spine

Include a section only when it has useful content. Combine sections for small changes and expand them for cross-system work.

1. **Objective** — visible outcome and observable completion criteria.
2. **Requirements and non-goals** — requested behavior and explicit boundaries.
3. **Current implementation** — relevant code path, constraints, and reusable patterns.
4. **Recommended design** — proposed data/control flow and repository-grounded rationale.
5. **Files and interfaces** — concrete components expected to change, with code anchors where verified.
6. **Implementation sequence** — ordered phases, prerequisites, deliverables, and dependencies.
7. **Failure handling** — invalid inputs, partial failure, retries, consistency, and recovery where relevant.
8. **Verification** — focused tests plus end-to-end behavior to observe.
9. **Rollout and rollback** — compatibility, migration, feature flags, deployment order, and reversal where relevant.
10. **Risks, assumptions, and open decisions** — honest caveats without generic filler.

## Phase quality

Each implementation phase should answer:

- What changes?
- Where does it change?
- Why is this the right layer?
- What does it depend on?
- How is completion verified?

Prefer a stepped progression for sequential work. Use tables for file inventories, risks, and acceptance criteria. Use prose for rationale and trade-offs. Avoid large pasted code blocks; summarize and cite the source instead.

## Questions

Ask only when a missing answer changes architecture, security/privacy, irreversible behavior, or a major user-visible trade-off. Use sensible defaults for formatting and low-impact implementation details, and state the default in the plan.
