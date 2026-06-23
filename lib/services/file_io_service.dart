import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'platform/file_writer.dart';

/// A file the user picked: its name plus its bytes (bytes work on every platform
/// including web, which has no path).
class PickedDocument {
  const PickedDocument(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

enum DeliveryKind { saved, shared, cancelled }

class DeliveryResult {
  const DeliveryResult(this.kind, [this.location]);
  final DeliveryKind kind;
  final String? location;
}

/// Picking files in, and getting marked files back out (save on desktop, share
/// on mobile/web) — all without a hard `dart:io` dependency.
class FileIoService {
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Opens the system file picker. Returns `null` if the user cancels.
  Future<PickedDocument?> pick() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedDocument(file.name, bytes);
  }

  /// Delivers [bytes] as [filename]: a save dialog on desktop, the share sheet
  /// on mobile/web.
  Future<DeliveryResult> deliver(Uint8List bytes, String filename) async {
    if (_isDesktop) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save watermarked file',
        fileName: filename,
      );
      if (path == null) return const DeliveryResult(DeliveryKind.cancelled);
      await writeBytesToPath(path, bytes);
      return DeliveryResult(DeliveryKind.saved, path);
    }

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: filename, mimeType: _mimeFor(filename))],
      fileNameOverrides: [filename],
    );
    return const DeliveryResult(DeliveryKind.shared);
  }
}

String _mimeFor(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    case 'txt':
    case 'text':
    case 'log':
    case 'rst':
      return 'text/plain';
    case 'md':
    case 'markdown':
      return 'text/markdown';
    case 'html':
    case 'htm':
    case 'xhtml':
      return 'text/html';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
