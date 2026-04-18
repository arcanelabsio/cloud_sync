#!/usr/bin/env bash
# Create and push a release tag for a single cloud_sync package.
#
# Usage:
#   scripts/tag.sh <package>
#
# <package> can be either the short name (core, drive, s3, box) or the
# full package name (cloud_sync_core, cloud_sync_drive, ...).
#
# The script reads the target version from the package's pubspec.yaml,
# validates that the release is safe to tag, and pushes the tag to origin.
# The publish.yaml workflow on GitHub Actions picks up the tag and handles
# the pub.dev upload.

set -euo pipefail

if [ $# -lt 1 ]; then
  cat <<'EOF' >&2
Usage: scripts/tag.sh <package>

  package: core | drive | s3 | box
           (or cloud_sync_core | cloud_sync_drive | ...)

Example:
  scripts/tag.sh drive
EOF
  exit 2
fi

PKG="$1"

# Normalize short names to full package names.
case "$PKG" in
  core|drive|s3|box) PKG="cloud_sync_$PKG" ;;
esac

# Must be run from the monorepo root (or a direct subdirectory of it).
# Find the repo root so we don't depend on where the user invoked from.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi
cd "$REPO_ROOT"

PKG_DIR="packages/$PKG"
if [ ! -d "$PKG_DIR" ]; then
  echo "error: $PKG_DIR does not exist" >&2
  echo "       known packages: cloud_sync_core, cloud_sync_drive, cloud_sync_s3, cloud_sync_box" >&2
  exit 1
fi

PUBSPEC="$PKG_DIR/pubspec.yaml"
VERSION=$(awk '/^version:/ {print $2; exit}' "$PUBSPEC")
if [ -z "$VERSION" ]; then
  echo "error: could not read version from $PUBSPEC" >&2
  exit 1
fi

TAG="${PKG}-v${VERSION}"

# --- preconditions ----------------------------------------------------------

# 1. Current branch must be main.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "error: releases must be tagged from main (currently on '$CURRENT_BRANCH')" >&2
  echo "       run 'git checkout main' first" >&2
  exit 1
fi

# 2. Working tree must be clean — no uncommitted or untracked files that
#    could be silently excluded from the release.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: working tree has uncommitted changes" >&2
  echo "       commit or stash before tagging" >&2
  exit 1
fi

# 3. Local main must be up to date with origin.
git fetch origin main --quiet
LOCAL=$(git rev-parse main)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" != "$REMOTE" ]; then
  echo "error: local main is not in sync with origin/main" >&2
  echo "       local:  $LOCAL" >&2
  echo "       remote: $REMOTE" >&2
  echo "       pull or push before tagging" >&2
  exit 1
fi

# 4. Tag must not already exist (locally or on the remote).
if git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists locally" >&2
  echo "       bump $PKG version in pubspec.yaml first" >&2
  exit 1
fi
if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
  echo "error: tag $TAG already exists on origin" >&2
  echo "       bump $PKG version in pubspec.yaml first" >&2
  exit 1
fi

# 5. This version must not already be published on pub.dev (prevents a
#    wasted CI run that would fail at the publish step anyway).
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://pub.dev/api/packages/$PKG/versions/$VERSION" || echo 000)
if [ "$HTTP_STATUS" = "200" ]; then
  echo "error: $PKG $VERSION is already published on pub.dev" >&2
  echo "       bump the version in $PUBSPEC first" >&2
  exit 1
fi

# --- execute ----------------------------------------------------------------

echo "Tagging $PKG @ $VERSION"
echo "  tag:    $TAG"
echo "  commit: $(git rev-parse --short HEAD)"
echo ""

git tag "$TAG"
git push origin "$TAG"

echo ""
echo "Tag pushed. Publish workflow should now be running:"
REPO_URL=$(git config --get remote.origin.url | sed -e 's#\.git$##' -e 's#git@github.com:#https://github.com/#')
echo "  $REPO_URL/actions"
