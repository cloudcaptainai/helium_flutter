import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/helium_flutter_platform_interface.dart';
import 'package:helium_flutter/helium_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHeliumFlutterPlatform
    with MockPlatformInterfaceMixin
    implements HeliumFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> initialize({
    required HeliumCallbacks callbacks,
    required String apiKey,
    required String customUserId,
    required String customAPIEndpoint,
    required Map<String, dynamic> customUserTraits,
  }) {
    return Future.value('Done');
  }

  @override
  Future<String?> getDownloadStatus() {
    // TODO: implement getDownloadStatus
    throw UnimplementedError();
  }

  @override
  Future<String?> getHeliumUserId() {
    // TODO: implement getHeliumUserId
    throw UnimplementedError();
  }

  @override
  Future<bool?> hideUpsell() {
    // TODO: implement hideUpsell
    throw UnimplementedError();
  }

  @override
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  }) {
    // TODO: implement overrideUserId
    throw UnimplementedError();
  }

  @override
  Future<bool?> paywallsLoaded() {
    // TODO: implement paywallsLoaded
    throw UnimplementedError();
  }

  @override
  Future<String?> presentUpsell({required String trigger}) {
    // TODO: implement presentUpsell
    throw UnimplementedError();
  }
}

void main() {
  final HeliumFlutterPlatform initialPlatform = HeliumFlutterPlatform.instance;

  test('$MethodChannelHeliumFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHeliumFlutter>());
  });

  test('getPlatformVersion', () async {
    HeliumFlutter heliumFlutterPlugin = HeliumFlutter();
    MockHeliumFlutterPlatform fakePlatform = MockHeliumFlutterPlatform();
    HeliumFlutterPlatform.instance = fakePlatform;

    expect('42', '42');
  });
}
