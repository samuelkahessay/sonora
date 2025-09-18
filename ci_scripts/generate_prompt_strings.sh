#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SWIFT_SOURCES=(
  "${REPO_ROOT}/Sonora/Domain/Models/RecordingPrompt.swift"
  "${REPO_ROOT}/Sonora/Domain/Protocols/PromptCatalog.swift"
  "${REPO_ROOT}/Sonora/Data/Services/Prompts/PromptCatalogStatic.swift"
  "${SCRIPT_DIR}/generate_prompt_strings.swift"
)

MODULE_CACHE="${REPO_ROOT}/.swift-module-cache"
mkdir -p "${MODULE_CACHE}"

BUILD_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t sonora_prompts)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

/usr/bin/swiftc -module-cache-path "${MODULE_CACHE}" "${SWIFT_SOURCES[@]}" -o "${BUILD_DIR}/generate_prompt_strings"
"${BUILD_DIR}/generate_prompt_strings" "$@"
