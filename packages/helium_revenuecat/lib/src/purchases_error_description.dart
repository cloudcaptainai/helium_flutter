import 'package:flutter/services.dart';

String describePurchasesError(PlatformException e) {
  final message = e.message ?? 'Unknown error';
  final details = e.details;
  final underlying = details is Map ? details['underlyingErrorMessage'] : null;
  final description = '$message code: ${e.code}';
  if (underlying is! String || underlying.isEmpty) return description;
  return '$description | $underlying';
}
