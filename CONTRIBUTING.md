# Contributing to cloud_sync

Thanks for considering a contribution. This guide describes how changes land cleanly — so your PR is reviewable, reversible, and easy to approve.

## Before you start

1. **Read [`AGENTS.md`](./AGENTS.md).** Rules, invariants, and where the contract lives.
2. **Read [`README.md`](./README.md).** High-level what and why, per-backend summaries, and the unified `SyncClient` API.
3. **Skim [`docs/adr/`](./docs/adr/).** ADRs explain why the current design is the way it is. Fighting an ADR without superseding it is a short road to a rejected PR.
4. **Skim the relevant package README** under `packages/cloud_sync_*/README.md` — the adapter you're touching almost certainly has backend-specific gotchas documented there.

## What kind of change are you making?

| Change type | Stakes | Where to work | Required |
|---|---|---|---|
| Typo or doc clarification | Low | Direct PR | — |
| Bug fix inside a single package | Medium | PR; consider opening an issue first if the fix has alternatives | Test that would have caught it |
| New feature inside a single adapter | Medium | PR; open an issue if you want alignment first | Tests + per-package README updated |
| Change to `StorageAdapter` / manifest / conflict / path-validation contracts | **High** | **Open an issue first** | ADR in `docs/adr/` + tests across every affected adapter |
| New backend adapter package | **High** | **Open an issue first** | ADR + the same 5-method surface as existing adapters + independent pub.dev entry |
| Breaking change to a published package | **Critical** | **Open an issue first** | ADR + migration notes + CHANGELOG entry |

When in doubt, open the issue first. The maintainer prefers five minutes of alignment over a large PR that needs reshaping.

## Development workflow

```bash
# Clone
git clone https://github.com/arcanelabsio/cloud_sync
cd cloud_sync

# Install melos + bootstrap the workspace
dart pub global activate melos
melos bootstrap        # or: make bootstrap

# Verify the happy path
melos run analyze      # or: make analyze
melos run test         # or: make test
```

`make help` lists every target. Under the hood, `make` wraps `melos run <script>` + `scripts/tag.sh` — use whichever you find more ergonomic.

### Running a single package's tests

```bash
cd packages/cloud_sync_drive
dart test
```

### When your change crosses package boundaries

A change in `cloud_sync_core` can break any adapter. Always run the full suite after touching the core:

```bash
melos run test
```

## Commit style

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(drive): add appData scope support
fix(core): preserve lastModified through conflict resolution
docs(adr): clarify SHA256-in-custom-metadata rationale
refactor(s3): extract SigV4 canonical-request builder
```

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.

The `<scope>` should be the affected package short name (`core`, `drive`, `s3`, `box`) or a cross-cutting subsystem (`ci`, `release`). Cross-package changes use the most impacted package as scope.

Do **not** include `Co-Authored-By:` trailers. The commit history is the record of intent; artificial attribution muddies it.

Keep commits small and focused — one logical change per commit makes review faster and `git bisect` meaningful later.

## Per-package versioning

Each `cloud_sync_*` package publishes independently on its own semver track. A change to `cloud_sync_drive` does not require a bump to `cloud_sync_s3`. When a PR bumps a package version:

1. Bump `version:` in `packages/<pkg>/pubspec.yaml`.
2. Add a matching entry to `packages/<pkg>/CHANGELOG.md`.
3. `cloud_sync_core` bumps ripple downstream — adapter packages should pin a compatible core constraint and be tested against the new core before a core release.

Tagging is gated on a clean tree; see [release workflow](./README.md#release-workflow).

## Pull request checklist

- [ ] PR description explains **what, why, and how it was validated**
- [ ] Tests added or updated for the behavior change
- [ ] Structural changes include an ADR in `docs/adr/`
- [ ] `README`, per-package `README`, `AGENTS.md`, or other docs updated if the contract changed
- [ ] `melos run analyze` and `melos run test` pass locally
- [ ] If version bumped: matching `CHANGELOG.md` entry in the package directory
- [ ] CI is green
- [ ] No secrets, API keys, or personal data in the diff

## Reporting bugs and proposing features

Use the issue templates under [`.github/ISSUE_TEMPLATE/`](./.github/ISSUE_TEMPLATE/). Good issues include:

- **What you were trying to do**
- **What happened instead**
- **Which package and version** — e.g., `cloud_sync_drive 0.1.1`
- **Why it matters** — the use case, not just the symptom
- **Suggested direction** (optional)

## Security

See [`SECURITY.md`](./SECURITY.md). Do **not** open public issues for security reports.

## Code of Conduct

By participating you agree to uphold the [`Code of Conduct`](./CODE_OF_CONDUCT.md).

---

Maintained by **Arcane Labs** · apps@arcanelabs.info
