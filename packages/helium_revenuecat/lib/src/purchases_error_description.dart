import 'package:flutter/services.dart';

String describePurchasesError(PlatformException e) {
  final message = e.message ?? 'Unknown error';
  final details = e.details;
  final underlying =
      details is Map ? details['underlyingErrorMessage'] as String? : null;
  final description = '$message code: ${e.code}';
  if (underlying == null || underlying.isEmpty) return description;
  return '$description | $underlying';
}
