import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

Future<XFile> quranShareImageFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  return XFile.fromData(bytes, mimeType: 'image/png', name: fileName);
}
