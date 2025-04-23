import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'helium_flutter_platform_interface.dart';
export './core/helium_callbacks.dart';
export './types/helium_paywall_event.dart';
export './types/helium_transaction_status.dart';

class HeliumFlutter {
  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required String apiKey,
    required String customUserId,
    required String customAPIEndpoint,
    required Map<String, dynamic> customUserTraits,
  }) async {
    return await HeliumFlutterPlatform.instance.initialize(
      apiKey: apiKey,
      callbacks: callbacks,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: customUserTraits,
    );
  }

  Future<String?> getDownloadStatus() =>
      HeliumFlutterPlatform.instance.getDownloadStatus();

  Future<String?> getHeliumUserId() =>
      HeliumFlutterPlatform.instance.getHeliumUserId();

  Future<bool?> hideUpsell() => HeliumFlutterPlatform.instance.hideUpsell();

  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) => HeliumFlutterPlatform.instance.overrideUserId(
    newUserId: newUserId,
    traits: traits,
  );

  Future<bool?> paywallsLoaded() =>
      HeliumFlutterPlatform.instance.paywallsLoaded();

  Future<String?> presentUpsell({required String trigger}) =>
      HeliumFlutterPlatform.instance.presentUpsell(trigger: trigger);
}

class UpsellViewForTrigger extends StatelessWidget {
  const UpsellViewForTrigger({super.key, this.trigger});
  final String viewType = 'upsellViewForTrigger';
  final String? trigger;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: trigger != null ? {'trigger': trigger} : {},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
