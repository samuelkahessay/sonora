#!/bin/sh

# Workaround for Xcode Cloud build issue where it fails to trust Swift Macros.
# This command globally sets the preference on the CI runner to skip macro validation,
# allowing the build to proceed.

set -e # Exit immediately if a command exits with a non-zero status.

echo "Applying Swift Macro validation workaround for Xcode Cloud..."

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

echo "Workaround applied successfully."
