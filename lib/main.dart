import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:signature_storage/signature_storage.dart';

import 'screens/home_shell.dart';
import 'services/document_service.dart';
import 'services/file_io_service.dart';
import 'services/identity_service.dart';
import 'services/identity_store.dart';
import 'services/pdf/pdf_handler.dart';
import 'services/platform/template_backend.dart';
import 'services/secure_storage_backend.dart';
import 'services/template_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final templateService =
      TemplateService(SignatureTemplateStore(await createTemplateBackend()));
  unawaited(templateService.load());

  // Native: private key in the OS secure keychain. Web: in-memory only — no
  // private key is ever stored in the browser (signing is native-only).
  final TemplateStorageBackend identityBackend = kIsWeb
      ? MemoryTemplateStorageBackend()
      : SecureStorageBackend('watermark.identity');
  final identityService = IdentityService(IdentityStore(identityBackend));
  unawaited(identityService.load());

  // Wire in the real (Flutter-backed) PDF handler, replacing the stub.
  final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final documentService = DocumentService()
    ..register(PdfHandler(
        fontData.buffer.asUint8List(fontData.offsetInBytes, fontData.lengthInBytes)));

  runApp(WaterMarkApp(
    templateService: templateService,
    identityService: identityService,
    documentService: documentService,
  ));
}

class WaterMarkApp extends StatelessWidget {
  const WaterMarkApp({
    super.key,
    required this.templateService,
    required this.identityService,
    required this.documentService,
  });

  final TemplateService templateService;
  final IdentityService identityService;
  final DocumentService documentService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: templateService),
        ChangeNotifierProvider.value(value: identityService),
        Provider.value(value: documentService),
        Provider(create: (_) => FileIoService()),
      ],
      child: MaterialApp(
        title: 'WaterMark',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}
