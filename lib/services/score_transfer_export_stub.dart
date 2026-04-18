import 'dart:typed_data';

import 'package:flutter/rendering.dart';

import '../models/portable_score_document.dart';

Future<void> exportScoreTransferDocument(
  PortableScoreDocument document, {
  required Uint8List bytes,
  required String fileName,
  Rect? sharePositionOrigin,
}) {
  throw UnsupportedError('Score export is unavailable on this platform.');
}
