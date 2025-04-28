import 'dart:developer';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  try {
    await integrationDriver(
      onScreenshot: (name, image, [args]) async {
        final File file = await File(
          'screenshots/$name.png',
        ).create(recursive: true);
        file.writeAsBytesSync(image);
        return true;
      },
    );
  } catch (e) {
    log('Error occured: $e');
  }
}
