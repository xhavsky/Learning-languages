import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'cef_api.dart';

/// Mapowanie ID maskotki/sklepu → plik GLB (Trellis).
String? glbAssetForId(String id) {
  const known = {
    'mascot_cat',
    'mascot_dog',
    'dress_sparkle',
    'bow_gold',
    'boots_pink',
    'tiara_crystal',
    'scarf_rainbow',
    'bowl_pink',
    'bowl_gold',
    'bed_soft',
    'bed_castle',
    'toy_mouse',
    'toy_ball',
    'plant_catnip',
    'lamp_moon',
  };
  if (!known.contains(id)) return null;
  return 'assets/models3d/$id.glb';
}

String mascotGlbId({required bool isDog}) =>
    isDog ? 'mascot_dog' : 'mascot_cat';

final _glbPresence = <String, bool>{};

Future<bool> glbAssetExists(String assetPath) async {
  final cached = _glbPresence[assetPath];
  if (cached != null) return cached;
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final ok = manifest.listAssets().contains(assetPath);
    _glbPresence[assetPath] = ok;
    return ok;
  } catch (_) {
    try {
      final raw = await rootBundle.loadString('AssetManifest.bin');
      final ok = raw.contains(assetPath);
      _glbPresence[assetPath] = ok;
      return ok;
    } catch (_) {
      _glbPresence[assetPath] = false;
      return false;
    }
  }
}

/// Jednolity podgląd GLB (orbit + zoom) na Lin / Win / Android / iOS.
///
/// - **Android / iOS / Web:** `model_viewer_plus` (systemowy WebView)
/// - **Linux / Windows / macOS:** `webview_cef` (Chromium — WebGL; WebKitGTK pada)
class TrellisStyleModelViewer extends StatelessWidget {
  const TrellisStyleModelViewer({
    super.key,
    required this.src,
    this.alt = 'Model 3D',
    this.autoRotate = true,
    this.backgroundColor = const Color(0xFF1A1A22),
  });

  final String src;
  final String alt;
  final bool autoRotate;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (useCefGlbViewer) {
      return buildCefGlbViewer(
        assetPath: src,
        alt: alt,
        autoRotate: autoRotate,
        backgroundColor: backgroundColor,
      );
    }
    return ColoredBox(
      color: backgroundColor,
      child: ModelViewer(
        key: ValueKey(src),
        src: src,
        alt: alt,
        backgroundColor: backgroundColor,
        ar: false,
        loading: Loading.eager,
        autoRotate: autoRotate,
        autoRotateDelay: 0,
        cameraControls: true,
        disableZoom: false,
        disablePan: false,
        touchAction: TouchAction.none,
        interactionPrompt: InteractionPrompt.auto,
        cameraOrbit: '0deg 75deg 105%',
        cameraTarget: '0m 0.45m 0m',
        fieldOfView: '30deg',
        minCameraOrbit: 'auto auto 40%',
        maxCameraOrbit: 'auto auto 300%',
        environmentImage: 'neutral',
        shadowIntensity: 0.6,
        exposure: 1.1,
      ),
    );
  }
}

/// Pełnoekranowy podgląd 3D (obrót / zoom) — ten sam silnik co w karcie.
Future<void> openModel3dPreview(
  BuildContext context, {
  required String assetPath,
  required String title,
}) async {
  if (!await glbAssetExists(assetPath)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brak modelu 3D: $title (jeszcze się generuje)')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _GlbFullscreenPage(
        assetPath: assetPath,
        title: title,
      ),
    ),
  );
}

class _GlbFullscreenPage extends StatelessWidget {
  const _GlbFullscreenPage({
    required this.assetPath,
    required this.title,
  });

  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121218),
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Przeciągnij — obrót · szczypnij / scroll — zoom',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: TrellisStyleModelViewer(
              src: assetPath,
              alt: title,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portret maskotki: GLB gdy jest, inaczej [fallback].
class Mascot3dOrFallback extends StatefulWidget {
  const Mascot3dOrFallback({
    super.key,
    required this.isDog,
    required this.size,
    required this.fallback,
    this.onTapOpenPreview,
  });

  final bool isDog;
  final double size;
  final Widget fallback;
  final VoidCallback? onTapOpenPreview;

  @override
  State<Mascot3dOrFallback> createState() => _Mascot3dOrFallbackState();
}

class _Mascot3dOrFallbackState extends State<Mascot3dOrFallback> {
  String? _src;
  var _checked = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant Mascot3dOrFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDog != widget.isDog) _resolve();
  }

  Future<void> _resolve() async {
    final id = mascotGlbId(isDog: widget.isDog);
    final path = glbAssetForId(id);
    var ok = false;
    if (path != null) ok = await glbAssetExists(path);
    if (!mounted) return;
    setState(() {
      _src = ok ? path : null;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _src == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.fallback,
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TrellisStyleModelViewer(src: _src!, alt: 'Maskotka'),
            Positioned(
              right: 4,
              bottom: 4,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: widget.onTapOpenPreview,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.fullscreen, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Text(
                  'Przeciągnij · zoom',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
