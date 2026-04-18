# Architecture Decision Records — cloud_sync

Numbered records of architectural decisions across the `cloud_sync` monorepo. Each ADR captures the context, the options considered, and the decision taken, so future-us remember why the code looks the way it does.

## Conventions

- Numbering is sequential, zero-padded to 4 digits (`ADR-0001`, `ADR-0002`). The `0000-TEMPLATE.md` file is not itself an ADR — copy it when authoring a new one.
- Status is one of `Proposed`, `Accepted`, `Superseded`, `Deprecated`.
- **ADRs are immutable after acceptance.** If the decision changes, supersede the old ADR with a new one and set the old to `Superseded`. Do not edit the record of the past.
- When an ADR applies to a single package, note it in the `scope:` frontmatter field (e.g., `scope: cloud_sync_drive`). Cross-package ADRs use `scope: monorepo`.

## When to write one

- Changing the **`StorageAdapter` contract** (the 5-method interface) or the **`SyncManifest` shape**.
- Changing **conflict-resolution semantics**, **path-validation rules**, or **SHA256 preservation strategy**.
- Adding a **new backend adapter** — adapters ship with an ADR explaining auth model, quirks, and how SHA256 is preserved.
- Changing a **trust boundary** (who can see what in Google Drive via scope changes, etc.).
- Picking a **release / publishing model** (independent per-package vs. lockstep) or swapping CI providers.
- **Removing** something non-trivial (a scope, a backend, a default) and wanting the reason to survive.
- A reviewer asks "why did we do it this way?" more than once.

If the decision fits in a commit message, a commit message is fine. ADRs are for decisions whose rationale is too long for a message and too load-bearing to lose.

## Authoring

Copy `0000-TEMPLATE.md` to the next number, fill in each section, and open a PR. The ADR lands with the code change it describes.

## Index

<!-- Update this index as ADRs land. -->

- _No ADRs yet. Backfilling the four highest-stakes decisions from the Phase 1–3 work is a known task:_
  1. _Split `drive_sync_flutter` into a storage-agnostic core + per-backend adapters (monorepo structure)._
  2. _Independent per-package versioning over lockstep releases._
  3. _Preserve SHA256 across backends without native SHA256 via custom metadata (S3 `x-amz-meta-sha256`, Box `/files/{id}/metadata/global/properties`)._
  4. _50MB single-request ceiling in v1; defer streaming/multipart to a later breaking change._
