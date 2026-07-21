import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialectium/main.dart';
import 'package:dialectium/storage.dart';
import 'package:dialectium/ui_fx.dart';

import 'screenshot_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generate mobile screenshots', (tester) async {
    enableScreenshotModeForTests();
    BazaStore.forceScreenshotFixture = true;
    addTearDown(() {
      BazaStore.forceScreenshotFixture = false;
    });

    await initScreenshotTest(tester);

    await tester.pumpWidget(
      const RepaintBoundary(
        key: screenshotRootKey,
        child: DialectiumApp(),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await pumpUntilReady(tester, timeout: const Duration(seconds: 30));
    // ignore: avoid_print
    print('ready — capturing…');

    await captureScreenshot(tester, '01-nauka');
    print('ok 01');

    await tester.tap(find.byKey(navWordsKey));
    print('tapped words');
    await tester.pump(const Duration(milliseconds: 600));
    print('pumped words');
    await captureScreenshot(tester, '02-slowka');
    print('ok 02');

    await tester.tap(find.byKey(navMascotKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    print('tapped mascot');
    await captureScreenshot(tester, '03-maskotka');
    print('ok 03');

    await openMoreAndSelect(tester, const ValueKey('more_shop'));
    print('opened shop');
    await captureScreenshot(tester, '04-sklep');
    print('ok 04');

    await openMoreAndSelect(tester, const ValueKey('more_pools'));
    print('opened pools');
    await captureScreenshot(tester, '05-pule');
    print('ok 05');

    await openMoreAndSelect(tester, const ValueKey('more_settings'));
    print('opened settings');
    await captureScreenshot(tester, '06-ustawienia');
    print('ok 06');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
