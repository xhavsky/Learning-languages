import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const screenshotRootKey = ValueKey('screenshot_root');

const navLearnKey = ValueKey('nav_learn');
const navWordsKey = ValueKey('nav_words');
const navMascotKey = ValueKey('nav_mascot');
const navMoreKey = ValueKey('nav_more');

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';

  @override
  Future<String?> getLibraryPath() async => '${root.path}/library';

  @override
  Future<String?> getApplicationDocumentsPath() async => '${root.path}/docs';

  @override
  Future<String?> getExternalStoragePath() async => '${root.path}/ext';

  @override
  Future<List<String>?> getExternalCachePaths() async =>
      ['${root.path}/ext_cache'];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      ['${root.path}/ext_storage'];

  @override
  Future<String?> getDownloadsPath() async => '${root.path}/downloads';
}

Directory screenshotOutputDir() {
  final fromEnv = Platform.environment['SCREENSHOT_OUTPUT_DIR'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    return Directory(fromEnv.trim());
  }
  return Directory('dist/screenshots/mobile');
}

Future<void> initScreenshotTest(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'themeMode': 'dark',
    'palette': 'mint',
    'uiLang': 'pl',
  });

  // Prawdziwe I/O w widget testach wymaga runAsync (fake async zone).
  final tmp = await tester.runAsync(
    () => Directory.systemTemp.createTemp('dialectium_screenshots_'),
  );
  if (tmp == null) {
    throw StateError('createTemp returned null');
  }
  await tester.runAsync(() async {
    await Directory('${tmp.path}/docs').create(recursive: true);
    await Directory('${tmp.path}/tmp').create(recursive: true);
  });
  PathProviderPlatform.instance = _FakePathProvider(tmp);
  addTearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpUntilReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(navLearnKey).evaluate().isNotEmpty &&
        find.byKey(navMoreKey).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 800));
      return;
    }
    // Fallback: NavigationBar already visible (keys optional).
    if (find.byType(NavigationBar).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // Spinner may still exist in XP/mascot widgets — check for quiz chrome.
      if (find.textContaining('XP').evaluate().isNotEmpty ||
          find.byKey(navMoreKey).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 800));
        return;
      }
    }
    if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) {
      throw TestFailure('App boot failed (error screen visible)');
    }
  }
  throw TestFailure('App did not become ready within $timeout');
}

Future<void> captureScreenshot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 200));
  final finder = find.byKey(screenshotRootKey);
  expect(finder, findsOneWidget);
  final boundary = tester.renderObject(finder) as RenderRepaintBoundary;

  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });
  expect(bytes, isNotNull);

  // Odzyskaj binding po toImage — inaczej kolejne tap/gesture wiszą.
  await tester.pump();

  final dir = screenshotOutputDir();
  final file = File('${dir.path}/$name.png');
  await tester.runAsync(() async {
    await dir.create(recursive: true);
    await file.writeAsBytes(bytes!, flush: true);
  });
  // ignore: avoid_print
  print('screenshot → ${file.path} (${bytes!.length} B)');
}

Future<void> openMoreAndSelect(
  WidgetTester tester,
  Key moreItemKey,
) async {
  await tester.tap(find.byKey(navMoreKey));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  final tile = find.byKey(moreItemKey);
  expect(tile, findsOneWidget);
  await tester.tap(tile);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
}
