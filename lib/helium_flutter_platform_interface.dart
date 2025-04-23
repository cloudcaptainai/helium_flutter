import 'package:helium_flutter/core/helium_callbacks.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'helium_flutter_method_channel.dart';

abstract class HeliumFlutterPlatform extends PlatformInterface {
  /// Constructs a HeliumFlutterPlatform.
  HeliumFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static HeliumFlutterPlatform _instance = MethodChannelHeliumFlutter();

  /// The default instance of [HeliumFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelHeliumFlutter].
  static HeliumFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HeliumFlutterPlatform] when
  /// they register themselves.
  static set instance(HeliumFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required String apiKey,
    required String customUserId,
    required String customAPIEndpoint,
    required Map<String, dynamic> customUserTraits,
  }) async {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<String?> getDownloadStatus() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> presentUpsell({required String trigger}) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool?> hideUpsell() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> getHeliumUserId() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool?> paywallsLoaded() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
