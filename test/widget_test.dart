import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature_storage/signature_storage.dart';
import 'package:watermark/main.dart';
import 'package:watermark/services/document_service.dart';
import 'package:watermark/services/identity_service.dart';
import 'package:watermark/services/identity_store.dart';
import 'package:watermark/services/template_service.dart';

Future<WaterMarkApp> _app({String? identityName}) async {
  final templates =
      TemplateService(SignatureTemplateStore(MemoryTemplateStorageBackend()));
  await templates.load();
  final identity = IdentityService(IdentityStore(MemoryTemplateStorageBackend()));
  await identity.load();
  if (identityName != null) await identity.create(identityName);
  return WaterMarkApp(
    templateService: templates,
    identityService: identity,
    documentService: DocumentService(),
  );
}

Finder _navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  testWidgets('shell renders its sections and navigates', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(_navLabel('Mark'), findsOneWidget);
    expect(_navLabel('Check'), findsOneWidget);
    expect(_navLabel('Templates'), findsOneWidget);
    expect(_navLabel('Identity'), findsOneWidget);

    await tester.tap(_navLabel('Templates'));
    await tester.pumpAndSettle();
    expect(find.text('No templates yet'), findsOneWidget);
  });

  testWidgets('marking pasted text produces a watermarked result',
      (tester) async {
    // Tall viewport so the whole Mark screen lays out (the ListView is lazy).
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'the quick brown fox jumps over');

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Malcolm-2026');

    await tester.tap(find.text('Embed watermark'));
    await tester.pumpAndSettle();

    expect(find.text('Watermarked text'), findsOneWidget);
  });

  testWidgets('secure mode seals text using the saved identity',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _app(identityName: 'Malcolm'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Secure seal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sealing as Malcolm'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField).first, 'my confidential research text here');
    await tester.tap(find.text('Embed secure seal'));
    await tester.pumpAndSettle();

    expect(find.text('Watermarked text'), findsOneWidget);
  });
}
