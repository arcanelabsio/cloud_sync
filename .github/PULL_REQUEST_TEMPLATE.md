<!--
PR title should follow Conventional Commits:
  feat(<scope>): subject
  fix(<scope>): subject
  docs(adr): subject
Allowed types: feat, fix, chore, docs, refactor, test, ci.
Scope is usually a package short name: core | drive | s3 | box
No Co-Authored-By trailers.
-->

## What this changes

One paragraph. What behavior, file, or contract is different after this PR. Name the package(s) touched.

## Why

The motivation. A reviewer should be able to approve or push back on the *direction* from this section alone.

## How it was validated

What you ran, tested, or checked. Not "tests pass" — which tests, covering what edge case.

- [ ] `melos run analyze` clean
- [ ] `melos run test` passes
- [ ] Manual verification (describe)

## Checklist

- [ ] PR title follows Conventional Commits (see comment above)
- [ ] No `Co-Authored-By:` trailer
- [ ] Tests updated or added for the behavior change
- [ ] Structural changes include an ADR in `docs/adr/`
- [ ] Docs updated if the contract changed (`README.md`, per-package `README.md`, `AGENTS.md`)
- [ ] If a version was bumped, matching `CHANGELOG.md` entry in `packages/<pkg>/`
- [ ] No secrets, API keys, or personal data in the diff
- [ ] CI is green

## Related

- Closes #
- Related ADR: `docs/adr/NNNN-...`
