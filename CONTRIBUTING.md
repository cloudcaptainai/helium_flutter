# Releases and CI / CD

## GitHub Actions Workflows

This repository uses four automated workflows:

### 1. Test and Validate (`run-tests.yml`)

**Triggers:**
- Pull requests opened or updated against the `main` branch
- Called by other workflows

**What it does:**
- Sets up Flutter environment
- Installs dependencies with `flutter pub get` (workspace)
- For each package (helium_flutter and helium_revenuecat):
  - Runs code analysis with `flutter analyze`
  - Executes tests with `flutter test`
  - Validates publishing readiness with `flutter pub publish --dry-run`

### 2. Create Tag and Release (`create-release.yml`)

**Triggers:**
- Pushes to `main` branch that modify `packages/helium_flutter/pubspec.yaml`

**What it does:**
- Detects version changes by comparing current and previous helium_flutter `pubspec.yaml`
- If version changed:
    - Runs the test workflow (tests both packages)
    - Creates a git tag with the new version
    - Creates a GitHub release with auto-generated notes

This workflow handles the release preparation but does not publish to pub.dev directly.

### 3. Publish to pub.dev (`publish.yml`)

**Triggers:**
- When a version tag is pushed (format: `1.2.3`)

**What it does:**
- Publishes helium_flutter first, then helium_revenuecat
- Uses the official Dart team's reusable workflow for publishing
- Authenticates with pub.dev using OIDC (OpenID Connect)

This workflow follows the [official Dart automated publishing guide](https://dart.dev/tools/pub/automated-publishing#publishing-packages-using-github-actions) and uses secure, credential-free authentication.

### 4. Update iOS Dependency (`update-ios-dependency.yml`)

**Triggers:**
- Repository dispatch from helium-swift releases
- Manual workflow dispatch with version input

**What it does:**
- Updates Package.swift and podspec with new helium-swift version
- Bumps both helium_flutter and helium_revenuecat pubspec.yaml versions (patch increment)
- Adds changelog entries to both packages
- Creates a pull request with these changes

## Release Process

To release a new version:

1. **Update versions**: Modify the `version:` field in both `packages/helium_flutter/pubspec.yaml` and `packages/helium_revenuecat/pubspec.yaml`
2. **Update changelogs**: Add release notes to both `packages/helium_flutter/CHANGELOG.md` and `packages/helium_revenuecat/CHANGELOG.md`
3. **Update helium-swift dependency (optional)**: Update the dependency version in BOTH `ios/helium_flutter/Package.swift` and `ios/helium_flutter.podspec`
4. **Commit and push**: Push your changes to the `main` branch
5. **Automatic flow**:
    - Release workflow detects helium_flutter version change
    - Runs tests on both packages
    - Creates git tag and GitHub release
    - Tag creation triggers publish workflow
    - Both packages are published to pub.dev

## Updates from the helium-swift dependency

A new release from the helium-swift SDK should trigger a workflow that creates a PR in this repo with the new version.
You can also manually trigger this workflow with specified helium-swift version.
