import 'package:helium_flutter/helium_flutter.dart';

class InitializeValue {
  final String apiKey;
  final HeliumCallbacks callbacks;
  final String customAPIEndpoint;
  final String customUserId;
  final Map<String, dynamic> customUserTraits;

  InitializeValue({
    required this.apiKey,
    required this.callbacks,
    required this.customAPIEndpoint,
    required this.customUserId,
    required this.customUserTraits,
  });
}
