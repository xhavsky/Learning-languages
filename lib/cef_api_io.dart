import 'package:flutter/material.dart';

import 'desktop_cef_glb.dart';

export 'desktop_cef_glb.dart' show useCefGlbViewer, initDesktopGlbRuntime;

Widget buildCefGlbViewer({
  required String assetPath,
  String alt = 'Model 3D',
  bool autoRotate = true,
  Color backgroundColor = const Color(0xFF1A1A22),
}) {
  return CefGlbViewer(
    assetPath: assetPath,
    alt: alt,
    autoRotate: autoRotate,
    backgroundColor: backgroundColor,
  );
}
