# Helium Flutter SDK

Flutter wrapper around the native Helium iOS (Swift) and Android (Kotlin) SDKs. Exposes Helium's paywall and experiment functionality to Flutter apps via method channels.

We also maintain an Expo/React Native SDK (`helium-expo`) that wraps the same native SDKs. When making changes, the Expo SDK can serve as reference for how native API changes should be bridged. Note: the Expo SDK lives in a separate repo and is not available here.

## Architecture

- `packages/helium_flutter/lib/` — Dart public API, platform interface, and method channel implementation
- `packages/helium_flutter/ios/` — iOS plugin (Swift), bridges to `helium-swift` SDK
- `packages/helium_flutter/android/` — Android plugin (Kotlin), bridges to Helium Android SDK
- `packages/helium_revenuecat/` — Optional RevenueCat integration package
- `packages/helium_stripe/` — Optional Stripe One Tap Purchase integration package
- `example/` — Example app for development and testing

## Key Principles

- **Never crash.** This SDK is distributed to apps with millions of users. Prefer defensive error handling (try/catch, backup logic) over letting exceptions propagate. A swallowed error is always better than a crash.
- **Follow Dart/Flutter conventions.** Do not strictly follow native iOS/Android patterns nor Expo context if provided.
- **Avoid using "fallback" in code and comments** unless referring to the Helium fallback paywall flow. This term has a specific meaning in this SDK.

## Testing

When adding or changing a method on `HeliumFlutterPlatform`, also update the `MockHeliumFlutterPlatform` in `packages/helium_flutter/test/helium_flutter_test.dart` — otherwise `flutter analyze` fails with `non_abstract_class_inherits_abstract_member` or `invalid_override`.
