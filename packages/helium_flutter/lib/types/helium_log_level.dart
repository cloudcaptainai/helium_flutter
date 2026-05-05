/// Helium log levels.
///
/// Setting a level emits log events at that level and all *less verbose*
/// levels. For example:
/// - [HeliumLogLevel.warn] emits warn + error
/// - [HeliumLogLevel.debug] emits debug + info + warn + error
enum HeliumLogLevel {
  off(0),
  error(1),
  warn(2),
  info(3),
  debug(4),
  trace(5);

  const HeliumLogLevel(this.rawValue);

  /// Integer value forwarded across the platform channel. Matches the raw
  /// values of `HeliumLogLevel` on both iOS and Android.
  final int rawValue;
}
