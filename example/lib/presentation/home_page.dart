import 'package:flutter/material.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter_example/presentation/revenue_cat_page.dart';
import 'package:helium_flutter_example/presentation/view_for_trigger_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _downloadState = 'Neutral';
  String _userId = 'Initial';
  bool _upsellHidden = false;
  bool _paywallsLoaded = false;

  final _heliumFlutterPlugin = HeliumFlutter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: Center(
        child: Column(
          children: [
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
                await _heliumFlutterPlugin.presentUpsell(
                      trigger: 'onboarding',
                    ) ??
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RevenueCatPage()),
                );
              },
              child: Text('Open RevenueCat Paywall'),
            ),
          ],
        ),
      ),
    );
  }
}
