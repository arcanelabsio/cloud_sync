# CHANGELOG

`cloud_sync` is a monorepo of independently versioned packages. Each package maintains its own `CHANGELOG.md`:

- [`cloud_sync_core`](packages/cloud_sync_core/CHANGELOG.md)
- [`cloud_sync_drive`](packages/cloud_sync_drive/CHANGELOG.md)
- [`cloud_sync_s3`](packages/cloud_sync_s3/CHANGELOG.md)
- [`cloud_sync_box`](packages/cloud_sync_box/CHANGELOG.md)

## Release history (monorepo-level)

| Date | Event |
|---|---|
| 2026-04-18 | All four packages published to pub.dev at `0.1.0`. |
| 2026-04-18 | All four packages bumped to `0.1.1` (CI-backed trusted publishing). |
| 2026-04-17 | `drive_sync_flutter 1.2.0` frozen; development moved to this monorepo. |

## Versioning policy

Each package follows semver independently. A breaking change in one adapter does **not** force a lockstep bump in any other. `cloud_sync_core` changes may ripple into adapter bumps — dependent adapters pin a compatible core constraint and are tested against the new core before their own release.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the release workflow and [`README.md`](README.md#release-workflow) for the exact tag-and-publish steps.
