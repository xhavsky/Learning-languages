import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opcjonalny portal współpracy (wyłączony w publicznych buildach).
/// Konfiguracja lokalna nie trafia do repo — patrz prywatne źródła maintainerów.
class PortalInfo {
  const PortalInfo({
    required this.enabled,
    required this.url,
    required this.urlIp,
    required this.pin,
    this.urlHttp = '',
    this.note = '',
  });

  final bool enabled;
  final String url;
  final String urlIp;
  final String pin;
  final String urlHttp;
  final String note;

  static const disabled = PortalInfo(
    enabled: false,
    url: '',
    urlHttp: '',
    urlIp: '',
    pin: '',
    note: '',
  );

  factory PortalInfo.fromJson(Map<String, dynamic> json) => PortalInfo(
        enabled: json['enabled'] as bool? ?? false,
        url: json['url'] as String? ?? '',
        urlHttp: json['urlHttp'] as String? ?? '',
        urlIp: json['urlIp'] as String? ?? '',
        pin: json['pin'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );

  static Future<PortalInfo> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/portal.json');
      return PortalInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return disabled;
    }
  }

  bool get isUsable =>
      enabled && url.trim().isNotEmpty && pin.trim().isNotEmpty;
}

/// Pokazuje dane portalu tylko gdy [PortalInfo.isUsable] (lokalna konfiguracja).
Future<void> showPortalSheet(
  BuildContext context, {
  required PortalInfo portal,
}) async {
  if (!portal.isUsable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portal współpracy jest wyłączony.')),
      );
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Portal współpracy',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText(
                portal.url,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (portal.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(portal.note, style: Theme.of(ctx).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: portal.url));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Skopiowano adres')),
                    );
                  }
                },
                child: const Text('Kopiuj adres'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
