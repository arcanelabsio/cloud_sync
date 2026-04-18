---
id: ADR-NNNN
title: Short declarative decision statement
status: Proposed
date: YYYY-MM-DD
scope: monorepo        # or: cloud_sync_core | cloud_sync_drive | cloud_sync_s3 | cloud_sync_box
supersedes: ADR-NNNN        # optional — if this ADR replaces a prior one
superseded_by: ADR-NNNN     # optional — filled in when THIS ADR is later superseded
---

## Context

What is the situation and what forces are in play? State the problem plainly, name the constraints (privacy, performance, scope, compatibility, cost, compliance), and make explicit any prior decisions the reader needs to know.

One or two paragraphs. If you need three, the context is probably two decisions tangled together.

## Options Considered

### Option A: <name>

Brief description.

- **Pro:** ...
- **Pro:** ...
- **Con:** ...

### Option B: <name>

Brief description.

- **Pro:** ...
- **Con:** ...
- **Con:** ...

### Option C: <name> (chosen)

Brief description of the chosen option. Include the subtle details — defaults, edge-case behavior, coupling points — that distinguish this option from A and B.

- **Pro:** ...
- **Pro:** ...
- **Con:** ...

Include enough options that the choice has contrast. One-option "ADRs" are memos, not decisions.

## Decision

**Option C.**

One paragraph stating the chosen option in unambiguous terms, and naming the **one-line reason** it beats the alternatives. A future reader should be able to read just this paragraph and know what was decided and why — everything above is supporting material.

## Consequences

### Positive

- ...
- ...

### Negative

- ...
- ...

### Risks

- **<Risk name>.** What could go wrong, and the mitigation. Risks that have no mitigation go here too — better to name them explicitly than leave them implicit.
- **<Risk name>.** ...

## Related Decisions

- [ADR-NNNN](NNNN-slug.md) — how this decision relates.

<!--
Guidance for authors (remove this block before merging):

- Keep ADRs short. 1–2 pages is the target; 3+ pages suggests you're blending rationale with design-doc content that should live elsewhere.
- Write for a reader who hasn't seen the PR. ADRs outlive PR review threads.
- Don't summarize the code. The code is authoritative for what it does. The ADR is authoritative for why.
- Status: `Proposed` while the PR is open, `Accepted` on merge. `Superseded` when replaced. `Deprecated` when the decision no longer applies but no replacement exists yet.
- Name the ADR with the pattern `NNNN-short-slug.md` (e.g., `0001-monorepo-split.md`).
- Set `scope:` to the most specific applicable value. Adapter-only decisions scope to that package.
-->
