import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter_example/core/payment_callbacks.dart';
import 'package:helium_flutter_example/presentation/revenue_cat_page.dart';
import 'package:helium_flutter_example/presentation/view_for_trigger_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _initialization = 'Start';
  String _downloadState = 'Neutral';
  String _userId = 'Initial';
  bool _upsellHidden = false;
  bool _paywallsLoaded = false;

  final _heliumFlutterPlugin = HeliumFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String initialization;
    PaymentCallbacks paymentCallbacks = PaymentCallbacks();
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      initialization =
          await _heliumFlutterPlugin.initialize(
            apiKey: 'sk-your-api-key',
            callbacks: paymentCallbacks,
            customAPIEndpoint: 'https://api-v2.tryhelium.com/on-launch',
            customUserId: 'asldkfj',
            customUserTraits: {
              'exampleUserTrait': 'test_value',
              'somethingElse': 'somethingElse',
              'somethingElse2': 'somethingElse2',
              'vibes': 3.0,
            },
          ) ??
          'Failed to initialize';
    } on PlatformException {
      initialization = 'Failed!';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _initialization = initialization;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: Column(
        children: [
          Center(child: Text(_initialization)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              String status =
                  await _heliumFlutterPlugin.getDownloadStatus() ?? '';
              setState(() {
                _downloadState = status;
              });
            },
            child: Text('Download status'),
          ),
          SizedBox(height: 8),
          Text(_downloadState),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              String result =
                  await _heliumFlutterPlugin.getHeliumUserId() ?? '';
              setState(() {
                _userId = result;
              });
            },
            child: Text('Get User Id'),
          ),
          SizedBox(height: 8),
          Text(_userId),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              bool result = await _heliumFlutterPlugin.hideUpsell() ?? false;
              setState(() {
                _upsellHidden = result;
              });
            },
            child: Text('Is upsell hidden?'),
          ),
          SizedBox(height: 8),
          Text(_upsellHidden.toString()),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              bool result =
                  await _heliumFlutterPlugin.paywallsLoaded() ?? false;
              setState(() {
                _paywallsLoaded = result;
              });
            },
            child: Text('Is paywall loaded?'),
          ),
          SizedBox(height: 8),
          Text(_paywallsLoaded.toString()),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await _heliumFlutterPlugin.presentUpsell(trigger: 'onboarding') ??
                  '';
            },
            child: Text('Present upsell'),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ViewForTriggerPage()),
              );
            },
            child: Text('Open View for Trigger'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RevenueCatPage()));
            },
            child: Text('Open RevenueCat Paywall'),
          ),
        ],
      ),
    );
  }
}
