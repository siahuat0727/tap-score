import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/portable_score_document.dart';

Future<void> exportScoreTransferDocument(
  PortableScoreDocument document, {
  required Uint8List bytes,
  required String fileName,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
      ],
      title: document.name,
      subject: document.name,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
