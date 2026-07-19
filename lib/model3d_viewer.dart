import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

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
    // NIE używamy rootBundle.load() — ładuje cały GLB do RAMu.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final ok = manifest.listAssets().contains(assetPath);
    _glbPresence[assetPath] = ok;
    return ok;
  } catch (_) {
    try {
      // Fallback starszych Flutterów
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

/// Podgląd GLB jak w Trellis: obrót (camera-controls) + pinch/scroll zoom + auto-rotate.
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
    // model_viewer_plus: WebView + @google/model-viewer (camera-controls, zoom).
    return ColoredBox(
      color: backgroundColor,
      child: ModelViewer(
        key: ValueKey(src),
        src: src,
        alt: alt,
        backgroundColor: backgroundColor,
        ar: false,
        autoRotate: autoRotate,
        autoRotateDelay: 0,
        cameraControls: true,
        disableZoom: false,
        disablePan: false,
        touchAction: TouchAction.none,
        interactionPrompt: InteractionPrompt.none,
        shadowIntensity: 1,
        exposure: 1,
      ),
    );
  }
}

/// Pełnoekranowy podgląd 3D (obrót / zoom).
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
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFF121218),
        child: SizedBox(
          width: MediaQuery.sizeOf(ctx).width,
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Przeciągnij — obrót · szczypnij / scroll — zoom',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  child: TrellisStyleModelViewer(
                    src: assetPath,
                    alt: title,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
    if (!_checked) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.fallback,
      );
    }
    if (_src == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.fallback,
      );
    }
    // Desktop Linux: WebView bywa kapryśny — zostaw 2D, podgląd w dialogu na mobile.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux)) {
      return GestureDetector(
        onTap: widget.onTapOpenPreview,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.fallback,
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.view_in_ar, size: 22, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
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
          ],
        ),
      ),
    );
  }
}
