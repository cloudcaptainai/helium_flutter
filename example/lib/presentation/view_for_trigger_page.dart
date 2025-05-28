import 'package:flutter/material.dart';
import 'package:helium_flutter/helium_flutter.dart';

class ViewForTriggerPage extends StatelessWidget {
  const ViewForTriggerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: HeliumFlutter().getUpsellWidget(trigger: "onboarding"));
  }
}
