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
              key: ValueKey('download_status'),
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
              key: ValueKey('user_id'),
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
              key: ValueKey('is_upsell_hidden'),
              onPressed: () async {
                bool result = await _heliumFlutterPlugin.hideUpsell();
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
              key: ValueKey('is_paywall_loaded'),
              onPressed: () async {
                bool result = await _heliumFlutterPlugin.paywallsLoaded();
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
              key: ValueKey('present_upsell'),
              onPressed: () async {
                await _heliumFlutterPlugin.presentUpsell(
                  trigger: 'sdk_test',
                  context: context,
                );
              },
              child: Text('Present upsell'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              key: ValueKey('view_for_trigger'),
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
