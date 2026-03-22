import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/portable_score_document.dart';
import 'score_transfer_web_download_stub.dart'
    if (dart.library.html) 'score_transfer_web_download_web.dart';

class ScoreTransferException implements Exception {
  const ScoreTransferException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'ScoreTransferException: $message'
        : 'ScoreTransferException: $message ($cause)';
  }
}

abstract class ScoreTransferService {
  Future<PortableScoreDocument?> importDocument();

  Future<void> exportDocument(
    PortableScoreDocument document, {
    required String fileName,
    Rect? sharePositionOrigin,
  });
}

class PlatformScoreTransferService implements ScoreTransferService {
  PlatformScoreTransferService({FilePicker? filePicker})
    : _filePicker = filePicker ?? FilePicker.platform;

  final FilePicker _filePicker;

  @override
  Future<PortableScoreDocument?> importDocument() async {
    final result = await _filePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
      withReadStream: false,
    );
    if (result == null) {
      return null;
    }
    if (result.files.isEmpty) {
      throw const ScoreTransferException('No file was selected.');
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const ScoreTransferException(
        'The selected file could not be read into memory.',
      );
    }

    try {
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const ScoreTransferException(
          'Imported file must contain a JSON object.',
        );
      }

      return PortableScoreDocument.fromJson(decoded);
    } on ScoreTransferException {
      rethrow;
    } catch (error) {
      throw ScoreTransferException(
        'Failed to import the selected score document.',
        cause: error,
      );
    }
  }

  @override
  Future<void> exportDocument(
    PortableScoreDocument document, {
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(document.toJson()),
      ),
    );

    try {
      if (kIsWeb) {
        downloadJsonFile(bytes: bytes, fileName: fileName);
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
          ],
          title: document.name,
          subject: document.name,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      throw ScoreTransferException(
        'Failed to export the current score.',
        cause: error,
      );
    }
  }
}
