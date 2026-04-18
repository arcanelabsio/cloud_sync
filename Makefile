.DEFAULT_GOAL := help

DART  ?= dart
MELOS ?= melos
PANA  ?= pana

PACKAGES := cloud_sync_core cloud_sync_drive cloud_sync_s3 cloud_sync_box

.PHONY: help bootstrap analyze lint test format format-fix publish-dry \
        release score clean pre-release ci all \
        check-melos check-pana

help:  ## Show this help message
	@awk 'BEGIN {FS = ":.*## *"; printf "\ncloud_sync Make targets:\n\n"} \
	  /^[a-zA-Z0-9_-]+:.*## / { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)
	@echo ""
	@echo "Release workflow:"
	@echo "  1. Bump version in packages/<pkg>/pubspec.yaml + update CHANGELOG.md"
	@echo "  2. git commit + git push main"
	@echo "  3. make pre-release        # analyze + test + publish dry-run"
	@echo "  4. make release PKG=<pkg>  # tag + push → publish.yaml runs"
	@echo ""

# ---------- setup ----------

check-melos:
	@command -v $(MELOS) >/dev/null 2>&1 || { \
	  echo "error: melos not found on PATH"; \
	  echo "  install:  dart pub global activate melos"; \
	  echo "  add path: export PATH=\"\$$HOME/.pub-cache/bin:\$$PATH\""; \
	  exit 1; \
	}

check-pana:
	@command -v $(PANA) >/dev/null 2>&1 || { \
	  echo "error: pana not found on PATH"; \
	  echo "  install:  dart pub global activate pana"; \
	  echo "  add path: export PATH=\"\$$HOME/.pub-cache/bin:\$$PATH\""; \
	  exit 1; \
	}

bootstrap: check-melos  ## Install deps + link workspace packages (melos bootstrap)
	$(MELOS) bootstrap

# ---------- quality gates ----------

analyze: check-melos  ## dart analyze across all packages
	$(MELOS) run analyze

lint: analyze  ## Alias for analyze

test: check-melos  ## dart test across all packages
	$(MELOS) run test

format: check-melos  ## Check formatting (fails if changes needed)
	$(MELOS) run format

format-fix: check-melos  ## Apply dart format to all packages
	$(MELOS) run format_fix

# ---------- release ----------

publish-dry: check-melos  ## dart pub publish --dry-run across all packages
	$(MELOS) run publish_dry

release:  ## Tag a package for release (PKG=core|drive|s3|box)
	@if [ -z "$(PKG)" ]; then \
	  echo "error: missing PKG argument"; \
	  echo "  usage: make release PKG=<package>"; \
	  echo "  PKG:   core | drive | s3 | box (or full cloud_sync_* name)"; \
	  exit 2; \
	fi
	./scripts/tag.sh $(PKG)

score: check-pana  ## Run pana on each package (pub.dev score preview; slow)
	@for pkg in $(PACKAGES); do \
	  printf "=== %s ===\n" "$$pkg"; \
	  (cd packages/$$pkg && $(PANA) 2>&1 | tail -3); \
	  echo ""; \
	done

# ---------- cleanup ----------

clean:  ## Remove .dart_tool, pubspec_overrides.yaml, build/ across workspace
	@find . -name ".dart_tool" -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@find . -name "pubspec_overrides.yaml" -delete 2>/dev/null || true
	@find . -name "build" -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@echo "cleaned .dart_tool/, pubspec_overrides.yaml, build/"

# ---------- composite ----------

pre-release: analyze test publish-dry  ## All preflight checks before tagging a release
	@echo ""
	@echo "\033[32m✓\033[0m Pre-release checks passed."
	@echo "  Next: make release PKG=<package>"

ci: bootstrap analyze test  ## What CI runs (bootstrap → analyze → test)

all: ci  ## Alias for ci
