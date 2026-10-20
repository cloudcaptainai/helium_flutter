# Helium Flutter SDK

Flutter plugin wrapping native iOS (Swift) and Android (Kotlin) Helium SDKs. See `CLAUDE.md` for architecture and key principles, `CONTRIBUTING.md` for release/CI workflows.

## Cursor Cloud specific instructions

### Prerequisites

Flutter SDK (stable) and Android SDK are installed at `/opt/flutter` and `/opt/android-sdk`. Both are on `PATH` via `~/.bashrc`.

### Quick reference

| Task | Command | Working directory |
|---|---|---|
| Install deps | `flutter pub get` | `/workspace` (root) |
| Analyze a package | `flutter analyze` | `packages/helium_flutter`, `packages/helium_revenuecat`, or `packages/helium_stripe` |
| Run tests | `flutter test` | Same as above |
| Analyze all | Run `flutter analyze` in each package directory |
| Build example APK | `flutter build apk --debug` | `example/` |
| Publish dry-run | `flutter pub publish --dry-run` | Individual package dir |

### Gotchas

- **Dart workspaces**: The root `pubspec.yaml` defines a workspace with all packages + example. A single `flutter pub get` at root resolves deps for everything — no need to run it per-package.
- **`.env` file required**: The example app expects `example/.env` (gitignored). Copy from `example/.env.example`. For CI/test purposes, empty string values are fine.
- **No iOS builds on Linux**: iOS plugin builds and `helium_stripe` (iOS-only) cannot compile on Linux VMs. Analysis and Dart unit tests still work.
- **Android SDK auto-downloads**: First `flutter build apk` may auto-download additional SDK components (NDK, CMake, extra platforms). This is expected and handled by Gradle.
- **No backend services needed**: All unit tests mock the platform channel. No databases, Docker, or external services are required.
