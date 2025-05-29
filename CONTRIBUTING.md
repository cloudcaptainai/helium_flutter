# Releases and CI / CD

## GitHub Actions Workflows

This repository uses three automated workflows to automate releases:

### 1. Test and Validate (`run-tests.yml`)

**Triggers:**
- Pull requests opened or updated against the `main` branch
- Called by other workflows

**What it does:**
- Sets up Flutter environment
- Installs dependencies with `flutter pub get`
- Runs code analysis with `flutter analyze`
- Executes tests with `flutter test`
- Validates publishing readiness with `flutter pub publish --dry-run`

### 2. Create Release and Publish (`create-release.yml`)

**Triggers:**
- Pushes to `main` branch that modify `pubspec.yaml`

**What it does:**
- Detects version changes by comparing current and previous `pubspec.yaml`
- If version changed:
    - Runs the test workflow
    - Creates a git tag with the new version
    - Creates a GitHub release with auto-generated notes

This workflow handles the release preparation but does not publish to pub.dev directly.

### 3. Publish to pub.dev (`publish.yml`)

**Triggers:**
- When a version tag is pushed (format: `1.2.3`)

**What it does:**
- Uses the official Dart team's reusable workflow for publishing
- Authenticates with pub.dev using OIDC (OpenID Connect)
- Publishes the package to pub.dev

This workflow follows the [official Dart automated publishing guide](https://dart.dev/tools/pub/automated-publishing#publishing-packages-using-github-actions) and uses secure, credential-free authentication.

## Release Process

To release a new version:

1. **Update version**: Modify the `version:` field in `pubspec.yaml`
2. **Update changelog**: Add release notes to `CHANGELOG.md` (remember to update both!)
3. **Update helium-swift dependency (optional)**: Update the dependency version in BOTH `ios/helium_flutter/Package.swift` and `ios/helium_flutter.podspec`
4. **Commit and push**: Push your changes to the `main` branch
5. **Automatic flow**:
    - Release workflow detects version change
    - Runs tests and if successful
    - Creates git tag and GitHub release
    - Tag creation triggers publish workflow
    - Package is published to pub.dev
