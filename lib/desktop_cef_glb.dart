import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_cef/webview_cef.dart';

bool _cefReady = false;

/// Desktop (Linux / Windows / macOS) — CEF ma prawdziwy Chromium + WebGL.
bool get useCefGlbViewer {
  if (kIsWeb) return false;
  try {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

Future<void> initDesktopGlbRuntime() async {
  if (!useCefGlbViewer || _cefReady) return;
  await WebviewManager().initialize(userAgent: 'Dialectium/3D');
  _cefReady = true;
}

/// Lokalny HTTP + model-viewer w CEF (orbit / zoom / fullscreen jak Trellis).
class CefGlbViewer extends StatefulWidget {
  const CefGlbViewer({
    super.key,
    required this.assetPath,
    this.alt = 'Model 3D',
    this.autoRotate = true,
    this.backgroundColor = const Color(0xFF1A1A22),
  });

  final String assetPath;
  final String alt;
  final bool autoRotate;
  final Color backgroundColor;

  @override
  State<CefGlbViewer> createState() => _CefGlbViewerState();
}

class _CefGlbViewerState extends State<CefGlbViewer> {
  WebViewController? _controller;
  HttpServer? _server;
  String? _error;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant CefGlbViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      unawaited(_restart());
    }
  }

  Future<void> _restart() async {
    await _teardown();
    if (mounted) await _start();
  }

  Future<void> _teardown() async {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await initDesktopGlbRuntime();
      final bytes = await rootBundle.load(widget.assetPath);
      final glb = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final js = await rootBundle.load(
        'packages/model_viewer_plus/assets/model-viewer.min.js',
      );
      final jsBytes = js.buffer.asUint8List(js.offsetInBytes, js.lengthInBytes);

      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;
      final bg =
          '#${widget.backgroundColor.toARGB32().toRadixString(16).substring(2)}';
      final auto = widget.autoRotate ? 'auto-rotate auto-rotate-delay="0"' : '';
      final altEsc = const HtmlEscape().convert(widget.alt);

      _server!.listen((req) async {
        final res = req.response;
        try {
          switch (req.uri.path) {
            case '/':
            case '/index.html':
              final html = '''
<!DOCTYPE html>
<html><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script type="module" src="/model-viewer.min.js"></script>
<style>
html,body{margin:0;width:100%;height:100%;background:$bg;overflow:hidden}
model-viewer{width:100%;height:100%;display:block}
</style>
</head><body>
<model-viewer src="/model.glb"
  alt="$altEsc"
  camera-controls touch-action="none"
  $auto
  camera-orbit="0deg 75deg 105%"
  camera-target="0m 0.45m 0m"
  field-of-view="30deg"
  min-camera-orbit="auto auto 40%"
  max-camera-orbit="auto auto 300%"
  environment-image="neutral"
  exposure="1.1"
  shadow-intensity="0.6"
  interaction-prompt="auto">
</model-viewer>
</body></html>
''';
              final data = utf8.encode(html);
              res
                ..statusCode = 200
                ..headers.contentType = ContentType.html
                ..headers.contentLength = data.length
                ..add(data);
            case '/model.glb':
              res
                ..statusCode = 200
                ..headers.set('Content-Type', 'model/gltf-binary')
                ..headers.contentLength = glb.length
                ..headers.set('Access-Control-Allow-Origin', '*')
                ..add(glb);
            case '/model-viewer.min.js':
              res
                ..statusCode = 200
                ..headers.set('Content-Type', 'application/javascript')
                ..headers.contentLength = jsBytes.length
                ..add(jsBytes);
            default:
              res.statusCode = 404;
          }
        } finally {
          await res.close();
        }
      });

      final controller = WebviewManager().createWebView(
        // webview_cef bug: null injectUserScripts → TypeError przy onBrowserCreated
        injectUserScripts: InjectUserScripts(),
        loading: ColoredBox(
          color: widget.backgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
      await controller.initialize('http://127.0.0.1:$port/');
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _ready = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '3D: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _controller!,
      builder: (_, ready, __) {
        return ready
            ? _controller!.webviewWidget
            : _controller!.loadingWidget;
      },
    );
  }
}
