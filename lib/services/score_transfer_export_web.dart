import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

import '../models/portable_score_document.dart';

Future<void> exportScoreTransferDocument(
  PortableScoreDocument document, {
  required Uint8List bytes,
  required String fileName,
  Rect? sharePositionOrigin,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';
  final body = web.document.body;
  if (body == null) {
    web.URL.revokeObjectURL(objectUrl);
    throw StateError('Document body is unavailable for download.');
  }

  body.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(objectUrl);
}
