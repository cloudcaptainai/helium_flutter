import 'package:flutter/material.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';

class ViewForTriggerPage extends StatelessWidget {
  const ViewForTriggerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: UpsellViewForTrigger(trigger: 'onboarding'));
  }
}
