import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatPage extends StatefulWidget {
  const RevenueCatPage({super.key});

  @override
  State<RevenueCatPage> createState() => _RevenueCatPageState();
}

class _RevenueCatPageState extends State<RevenueCatPage> {
  @override
  void initState() {
    getCustomerInfo();
    super.initState();
  }

  Future<void> getCustomerInfo() async {
    final offerings = await Purchases.getOfferings();
    log(offerings.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Center()));
  }
}
