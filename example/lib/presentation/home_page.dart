import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_config_status.dart';
import 'package:helium_flutter_example/presentation/view_for_trigger_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _heliumFlutterPlugin = HeliumFlutter();

  String? _heliumUserId;
  String? _anonymousId;

  String get _trigger {
    final value = dotenv.env['TRIGGER'];
    return (value == null || value.isEmpty) ? 'sdk_test' : value;
  }

  @override
  void initState() {
    super.initState();
    _refreshHeliumUserId();
  }

  Future<void> _refreshHeliumUserId() async {
    final id = await _heliumFlutterPlugin.getHeliumUserId();
    if (!mounted) return;
    setState(() => _heliumUserId = id);
  }

  Future<void> _setRandomUserId() async {
    await _heliumFlutterPlugin.overrideUserId(newUserId: _randomUuid());
    await _refreshHeliumUserId();
  }

  Future<void> _clearUserId() async {
    await _heliumFlutterPlugin.overrideUserId(newUserId: '');
    await _refreshHeliumUserId();
  }

  Future<void> _setRandomAnonymousId() async {
    final id = _randomUuid();
    await _heliumFlutterPlugin.setThirdPartyAnalyticsAnonymousId(id);
    if (!mounted) return;
    setState(() => _anonymousId = id);
  }

  Future<void> _clearAnonymousId() async {
    await _heliumFlutterPlugin.setThirdPartyAnalyticsAnonymousId(null);
    if (!mounted) return;
    setState(() => _anonymousId = null);
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
      appBar: AppBar(title: const Text('Flutter example app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<HeliumConfigStatus?>(
            stream: HeliumFlutter.downloadStatus,
            builder: (context, snapshot) {
              return Text('Helium Status ${snapshot.data?.name}');
            },
          ),
          _Section(
            title: 'User status',
            children: [
              _IdLabel(label: 'User ID', value: _heliumUserId),
              _ActionButton(
                buttonKey: const ValueKey('set_user_id'),
                label: 'Set random user ID',
                onPressed: _setRandomUserId,
              ),
              const SizedBox(height: 8),
              _IdLabel(
                label: 'Analytics anonymous ID',
                value: _anonymousId,
              ),
              _ActionButton(
                buttonKey: const ValueKey('set_anonymous_id'),
                label: 'Set random anonymous ID',
                onPressed: _setRandomAnonymousId,
              ),
              _ActionButton(
                buttonKey: const ValueKey('clear_anonymous_id'),
                label: 'Clear anonymous ID',
                onPressed: _clearAnonymousId,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: 'Check Entitlements',
                onPressed: _showEntitlements,
              ),
            ],
          ),
          _Section(
            title: 'Paywalls',
            children: [
              _ActionButton(
                buttonKey: const ValueKey('present_upsell'),
                label: 'Present upsell',
                onPressed: () async {
                  await _heliumFlutterPlugin.presentUpsell(
                    trigger: _trigger,
                    context: context,
                  );
                },
              ),
              _ActionButton(
                buttonKey: const ValueKey('view_for_trigger'),
                label: 'Open View for Trigger',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ViewForTriggerPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Extras',
            children: [
              _ActionButton(
                buttonKey: const ValueKey('reset_helium'),
                label: 'Reset Helium',
                onPressed: () async {
                  await _heliumFlutterPlugin.resetHelium();
                  await _heliumFlutterPlugin.initialize(
                    apiKey: dotenv.env['API_KEY'] ?? '',
                  );
                  await _refreshHeliumUserId();
                },
              ),
              _ActionButton(
                label: 'Open Paddle Portal',
                onPressed: _openPaddlePortal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _randomUuid() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String seg(int start, int end) => b
      .sublist(start, end)
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${seg(0, 4)}-${seg(4, 6)}-${seg(6, 8)}-${seg(8, 10)}-${seg(10, 16)}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _IdLabel extends StatelessWidget {
  const _IdLabel({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final display = (value == null || value!.isEmpty) ? '(none)' : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: $display',
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ElevatedButton(
            key: buttonKey,
            onPressed: onPressed,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
