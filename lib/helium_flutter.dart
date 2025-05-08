import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/const/contants.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
export './core/helium_callbacks.dart';
export './types/helium_transaction_status.dart';

class HeliumFlutter {
  ///Initialize helium sdk at the start up of flutter application. It will download custom paywall view
  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required Widget fallbackPaywall,
    required String apiKey,
    required String customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
  }) async {
    return await HeliumFlutterPlatform.instance.initialize(
      callbacks: callbacks,
      fallbackPaywall: fallbackPaywall,
      apiKey: apiKey,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: customUserTraits,
    );
  }

  ///Download status of paywall
  Future<String?> getDownloadStatus() =>
      HeliumFlutterPlatform.instance.getDownloadStatus();

  ///Gets helium user id
  Future<String?> getHeliumUserId() =>
      HeliumFlutterPlatform.instance.getHeliumUserId();

  ///Hides view
  Future<bool?> hideUpsell() => HeliumFlutterPlatform.instance.hideUpsell();

  ///Overrides user id to given [newUserId]
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) => HeliumFlutterPlatform.instance.overrideUserId(
    newUserId: newUserId,
    traits: traits,
  );

  ///Returns bool based on paywall loaded or not
  Future<bool?> paywallsLoaded() =>
      HeliumFlutterPlatform.instance.paywallsLoaded();

  ///Presents view based on [trigger]
  Future<String?> presentUpsell({required BuildContext context, required String trigger}) =>
      HeliumFlutterPlatform.instance.presentUpsell(context: context, trigger: trigger);
}

///This widget used to present view based on [trigger]
class UpsellViewForTrigger extends StatelessWidget {
  const UpsellViewForTrigger({super.key, this.trigger});
  final String viewType = upsellViewForTrigger;
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
