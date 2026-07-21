import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

Future<XFile> quranShareImageFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  if (!await file.exists() || await file.length() == 0) {
    throw StateError('Quran share image file was not written.');
  }
  return XFile(file.path, mimeType: 'image/png', name: fileName);
}
