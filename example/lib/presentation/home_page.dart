import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_config_status.dart';
import 'package:helium_flutter_example/presentation/revenue_cat_page.dart';
import 'package:helium_flutter_example/presentation/view_for_trigger_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userId = 'Initial';
  bool _upsellHidden = false;
  bool _paywallsLoaded = false;

  final _heliumFlutterPlugin = HeliumFlutter();


  String get _trigger {
    final value = dotenv.env['TRIGGER'];
    return (value == null || value.isEmpty) ? 'sdk_test' : value;
  }

  Widget getDownloadStatusText(BuildContext context) {
    return StreamBuilder<HeliumConfigStatus?>(
      stream: HeliumFlutter.downloadStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
          return Text("Helium Status ${status?.name}");
      },
    );
  }

  Future<void> _openPaddlePortal() async {
    final url = await _heliumFlutterPlugin.createPaddlePortalSession();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paddle Portal'),
        content: SelectableText(url ?? 'No URL returned'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntitlements() async {
    final hasSubscription =
        await _heliumFlutterPlugin.hasAnyActiveSubscription();
    final hasEntitlement = await _heliumFlutterPlugin.hasAnyEntitlement();
    final hasTriggerEntitlement =
        await _heliumFlutterPlugin.hasEntitlementForPaywall(_trigger);
    final hasPaddle = await _heliumFlutterPlugin.hasActivePaddleEntitlement();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entitlements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Any active subscription: $hasSubscription'),
            Text('Any entitlement: $hasEntitlement'),
            Text(
              'Entitlement for "$_trigger": '
              '${hasTriggerEntitlement ?? "unknown"}',
            ),
            Text('Active Paddle entitlement: $hasPaddle'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 8),
            getDownloadStatusText(context),
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
                  trigger: _trigger,
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
            SizedBox(height: 8),
            ElevatedButton(
              key: ValueKey('reset_helium'),
              onPressed: () async {
                await _heliumFlutterPlugin.resetHelium();
                await _heliumFlutterPlugin.initialize(
                  apiKey: dotenv.env['API_KEY'] ?? '',
                );
              },
              child: Text('Reset Helium'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RevenueCatPage()),
                );
              },
              child: Text('Open RevenueCat Paywall'),
            ),
            ElevatedButton(
              onPressed: _showEntitlements,
              child: Text('Check Entitlements'),
            ),
            ElevatedButton(
              onPressed: _openPaddlePortal,
              child: Text('Open Paddle Portal'),
            ),
          ],
        ),
      ),
    );
  }
}
