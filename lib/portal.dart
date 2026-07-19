import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Temporary Tailscale portal for Anielka (chat with Cursor agent + GH publish).
class PortalInfo {
  const PortalInfo({
    required this.url,
    required this.urlIp,
    required this.pin,
    this.urlHttp = '',
    this.note = '',
  });

  final String url;
  final String urlIp;
  final String pin;
  final String urlHttp;
  final String note;

  static const fallback = PortalInfo(
    url: 'https://nixos.tail4caf1.ts.net:7475',
    urlHttp: 'http://nixos.tail4caf1.ts.net:7474',
    urlIp: 'http://100.68.72.119:7474',
    pin: '3141',
    note:
        'Tailscale włączony. W OperaGX: HTTPS https://nixos.tail4caf1.ts.net:7475',
  );

  factory PortalInfo.fromJson(Map<String, dynamic> json) => PortalInfo(
        url: json['url'] as String? ?? fallback.url,
        urlHttp: json['urlHttp'] as String? ?? fallback.urlHttp,
        urlIp: json['urlIp'] as String? ?? fallback.urlIp,
        pin: json['pin'] as String? ?? fallback.pin,
        note: json['note'] as String? ?? fallback.note,
      );

  static Future<PortalInfo> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/portal.json');
      return PortalInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return fallback;
    }
  }
}

Future<Map<String, dynamic>> portalGithubPublish({
  required PortalInfo portal,
  required String username,
  required String token,
  required String repo,
}) async {
  final client = HttpClient();
  final bases = <String>{
    portal.url,
    if (portal.urlHttp.isNotEmpty) portal.urlHttp,
    portal.urlIp,
  };
  Object? lastErr;
  try {
    for (final base in bases) {
      try {
        final uri = Uri.parse('$base/api/github-publish');
        final req =
            await client.postUrl(uri).timeout(const Duration(seconds: 20));
        req.headers.set('Content-Type', 'application/json; charset=utf-8');
        req.headers.set('X-Portal-Pin', portal.pin);
        req.add(
          utf8.encode(
            jsonEncode({
              'pin': portal.pin,
              'username': username,
              'token': token,
              'repo': repo,
            }),
          ),
        );
        final res = await req.close().timeout(const Duration(minutes: 3));
        final body = await res.transform(utf8.decoder).join();
        try {
          return jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'ok': false,
            'error': 'Zła odpowiedź serwera (${res.statusCode})',
          };
        }
      } catch (e) {
        lastErr = e;
      }
    }
    return {
      'ok': false,
      'error':
          'Nie łączy z portalem ($lastErr). Tailscale + HTTPS ${portal.url}',
      'help': 'Spróbuj w Opera: ${portal.url}',
    };
  } finally {
    client.close(force: true);
  }
}

Future<void> showAnielkaPortalSheet(
  BuildContext context, {
  required PortalInfo portal,
}) async {
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
                'Portal Anielki (tymczasowy)',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu piszesz do asystenta o projekcie. Potrzebny Tailscale '
                '(to samo konto co tata) i PIN.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SelectableText(
                portal.url,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (portal.urlHttp.isNotEmpty)
                SelectableText(
                  'HTTP: ${portal.urlHttp}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              SelectableText(
                'IP: ${portal.urlIp}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'PIN: ${portal.pin}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              if (portal.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(portal.note, style: Theme.of(ctx).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: portal.url));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Skopiowano adres HTTPS')),
                    );
                  }
                },
                child: const Text('Kopiuj adres HTTPS'),
              ),
              const SizedBox(height: 16),
              Text(
                'Jak wejść (krok po kroku)',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '1. Na PC Anielki (FreeUnicorn) włącz Tailscale — Connected.\n'
                '2. OperaGX → wklej HTTPS (ważne):\n'
                '   ${portal.url}\n'
                '3. Certyfikat Tailscale: kontynuuj / zaawansowane → wejdź.\n'
                '4. PIN: ${portal.pin}\n'
                '5. Napisz, co zmienić — poczekaj na odpowiedź.\n'
                '6. Paczki: w portalu „Paczki / Release”.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showGithubPublishSheet(
  BuildContext context, {
  required PortalInfo portal,
}) async {
  final userCtrl = TextEditingController();
  final tokenCtrl = TextEditingController();
  final repoCtrl = TextEditingController(text: 'Learning-languages');
  var status = '';
  var busy = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
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
                    'Opublikuj na GitHub Anielki',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zrób to tak:\n'
                    '1. Wejdź na github.com i zaloguj się na SWOJE konto.\n'
                    '2. Otwórz: github.com/settings/tokens\n'
                    '3. „Generate new token” → „Generate new token (classic)”\n'
                    '4. Note: trener · zaznacz tylko „repo”\n'
                    '5. Generate token → skopiuj (zaczyna się od ghp_)\n'
                    '6. Wklej poniżej nazwę użytkownika i token.\n\n'
                    'Publikacja idzie przez portal taty (Tailscale musi działać).',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa użytkownika GitHub',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token (classic, repo)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: repoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa repozytorium',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setLocal(() {
                              busy = true;
                              status = 'Publikuję…';
                            });
                            final res = await portalGithubPublish(
                              portal: portal,
                              username: userCtrl.text.trim(),
                              token: tokenCtrl.text.trim(),
                              repo: repoCtrl.text.trim().isEmpty
                                  ? 'Learning-languages'
                                  : repoCtrl.text.trim(),
                            );
                            setLocal(() {
                              busy = false;
                              if (res['ok'] == true) {
                                status = res['message']?.toString() ??
                                    res['url']?.toString() ??
                                    'OK';
                                tokenCtrl.clear();
                              } else {
                                status =
                                    '${res['error'] ?? 'Błąd'}\n${res['help'] ?? ''}';
                              }
                            });
                          },
                    child: Text(busy ? 'Czekaj…' : 'Opublikuj na moje konto'),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(status, style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
