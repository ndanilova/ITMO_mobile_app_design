import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/dashboard.dart';
import 'package:saldo/design.dart';
import 'package:saldo/forms.dart';
import 'package:saldo/import_screen.dart';
import 'package:saldo/local_store.dart';

void main() {
  testWidgets(
    'Local data drives all tabs and the import confirms without network',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final directory = Directory.systemTemp.createTempSync('saldo-widget');
      final store = LocalStore(File('${directory.path}/data.json'));
      await tester.runAsync(store.seed);
      final font = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await tester.runAsync(font.load);
      final materialFont = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(materialFont.load);
      debugDisableShadows = false;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Manrope',
              scaffoldBackgroundColor: saldoBackground,
              colorScheme: ColorScheme.fromSeed(
                seedColor: saldoGreen,
                primary: saldoGreen,
              ),
            ),
            home: Dashboard(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        if (const bool.fromEnvironment('SALDO_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/previews/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      expect(find.text('Добавить'), findsOneWidget);
      await capture('operations');
      for (final label in ['Счета', 'Категории', 'Портфель', 'Статистика']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          {
            'Счета': 'accounts',
            'Категории': 'categories',
            'Портфель': 'portfolio',
            'Статистика': 'statistics',
          }[label]!,
        );
      }
      await tester.tap(find.text('Операции').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(find.byType(OperationForm), findsOneWidget);
      await capture('add-operation');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('2').last);
      await tester.tap(find.text(',').last);
      await tester.tap(find.text('5').last);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.check).last);
        while (store.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(OperationForm), findsNothing);
      final reopened = LocalStore(store.file);
      await tester.runAsync(reopened.load);
      expect(reopened.operations.any((o) => o.amount == 1250), isTrue);
      Navigator.of(tester.element(find.byType(Dashboard))).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AssetPage(store: store, account: 'broker', symbol: 'SU26238'),
        ),
      );
      await tester.pumpAndSettle();
      await capture('asset');
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AssetPage))).pop();
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(Dashboard))).push(
        MaterialPageRoute<void>(builder: (_) => ImportScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить на образце'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Подтвердить импорт'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Подтвердить импорт'));
        while (store.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Импорт сохранён на устройстве'), findsOneWidget);
      expect(store.trades.length, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
      debugDisableShadows = true;
      directory.deleteSync(recursive: true);
    },
  );
}
