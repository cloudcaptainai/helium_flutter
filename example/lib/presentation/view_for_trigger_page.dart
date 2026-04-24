import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter/helium_flutter.dart';

class ViewForTriggerPage extends StatelessWidget {
  const ViewForTriggerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final envTrigger = dotenv.env['TRIGGER'];
    final trigger = (envTrigger == null || envTrigger.isEmpty)
        ? 'sdk_test'
        : envTrigger;
    return Scaffold(body: HeliumFlutter().getUpsellWidget(trigger: trigger));
  }
}
