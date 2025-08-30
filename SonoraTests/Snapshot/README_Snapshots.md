# Sonora UI Snapshot Tests

This suite renders SwiftUI views to images and compares them to baselines.

- Light and Dark mode snapshots are captured at 390x844pt (iPhone 15).
- Images attach to test results. Mismatches fail the build with a diff summary.
- Baselines live under SonoraTests/Snapshot/Baselines/<Class>/<name>__<appearance>.png and are bundled with the test target.

## Record / Update Baselines

1) Run tests with recording enabled (local only):

RECORD_SNAPSHOTS=1 xcodebuild -scheme Sonora -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonoraTests

2) The new baseline paths are printed/attached. Commit the generated PNGs under SonoraTests/Snapshot/Baselines/.

3) Re-run tests without RECORD_SNAPSHOTS to verify they pass.

Notes:
- Test bundles are read-only at runtime, so recordings are written to the discovered Baselines folder when available or to a temporary directory; the test output includes the path to copy/commit.

## CI Integration

- Fails when a snapshot differs from its baseline or when a baseline is missing.
- To intentionally update CI baselines, run with RECORD_SNAPSHOTS=1 in a controlled job, commit changes, then re-run without record mode.

## Forcing Appearance in Launch (UI Tests)

For full UI automation tests (SonoraUITests), you can force appearance via launch arguments:

XCUIApplication().launchArguments += ["-AppleInterfaceStyle", "Dark"]

This snapshot suite sets appearance directly on the hosting window and does not require app launch.

## Determinism

- Animations are disabled during snapshot capture.
- Views are rendered off-screen via UIHostingController with fixed size.
- Feature ViewModels that self-initialize via DI are used passively; tests render initial UI states (for example, empty lists).

