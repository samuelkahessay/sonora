#!/usr/bin/env bash
set -euo pipefail

# SwiftLint runner for app, tests, and analyzer modes.
# Usage:
#   ci_scripts/lint_swift.sh app
#   ci_scripts/lint_swift.sh tests
#   ci_scripts/lint_swift.sh analyze-app
#   ci_scripts/lint_swift.sh analyze-tests

MODE=${1:-app}
BASELINE_FILE=".swiftlint.baseline.yml"

case "$MODE" in
  app)
    echo "Linting app targets with .swiftlint.app.yml"
    swiftlint lint --config .swiftlint.app.yml --baseline "$BASELINE_FILE" --no-cache
    ;;
  tests)
    echo "Linting test targets with .swiftlint.tests.yml"
    swiftlint lint --config .swiftlint.tests.yml --baseline "$BASELINE_FILE" --no-cache
    ;;
  analyze-app)
    echo "Analyzing app targets (requires compiler log)"
    if [[ ! -f build.log ]]; then
      echo "build.log not found. Run an xcodebuild that captures compiler logs first." >&2
      exit 1
    fi
    swiftlint analyze --config .swiftlint.app.yml --compiler-log-path build.log
    ;;
  analyze-tests)
    echo "Analyzing tests (requires compiler log)"
    if [[ ! -f build.log ]]; then
      echo "build.log not found. Run an xcodebuild that captures compiler logs first." >&2
      exit 1
    fi
    swiftlint analyze --config .swiftlint.tests.yml --compiler-log-path build.log
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 2
    ;;
esac

