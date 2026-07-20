import 'package:flutter/material.dart';

bool get useCefGlbViewer => false;

Future<void> initDesktopGlbRuntime() async {}

Widget buildCefGlbViewer({
  required String assetPath,
  String alt = 'Model 3D',
  bool autoRotate = true,
  Color backgroundColor = const Color(0xFF1A1A22),
}) {
  return ColoredBox(
    color: backgroundColor,
    child: const Center(child: Text('3D niedostępne')),
  );
}
