import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import 'quran_share_file.dart';
import 'quran_typography.dart';

const salatiShareLink = 'https://salati.app';

Future<XFile> buildQuranShareImage({
  required String title,
  required String body,
  required String reference,
  String? translation,
  String quranFontKey = 'amiri_quran',
  String filePrefix = 'salati_quran',
}) async {
  final bytes = await ScreenshotController().captureFromWidget(
    RepaintBoundary(
      child: SizedBox(
        width: 1080,
        child: _QuranShareCard(
          title: title,
          body: body,
          reference: reference,
          translation: translation,
          quranFontKey: quranFontKey,
        ),
      ),
    ),
    delay: const Duration(milliseconds: 120),
    pixelRatio: 2,
  );

  if (bytes.isEmpty) {
    throw StateError('Encoded Quran share image is empty.');
  }

  final fileName = quranShareImageFileName(
    filePrefix: filePrefix,
    reference: reference,
    timestamp: DateTime.now(),
  );

  return quranShareImageFile(bytes: bytes, fileName: fileName);
}

String quranShareImageFileName({
  required String filePrefix,
  required String reference,
  required DateTime timestamp,
}) {
  final safePrefix = _safeFileSegment(filePrefix, fallback: 'salati_quran');
  final safeReference = _safeFileSegment(reference, fallback: 'quran');
  return '${safePrefix}_${safeReference}_${timestamp.millisecondsSinceEpoch}.png';
}

String _safeFileSegment(String value, {required String fallback}) {
  final safe = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
  return safe.isEmpty ? fallback : safe;
}

class _QuranShareCard extends StatelessWidget {
  const _QuranShareCard({
    required this.title,
    required this.body,
    required this.reference,
    required this.quranFontKey,
    this.translation,
  });

  final String title;
  final String body;
  final String reference;
  final String? translation;
  final String quranFontKey;

  @override
  Widget build(BuildContext context) {
    final compactBody = compactQuranShareTextForImage(body);
    final compactTranslation = compactQuranShareTextForImage(translation ?? '');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1080, 1080)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 1080,
            constraints: const BoxConstraints(minHeight: 1080),
            padding: const EdgeInsets.all(58),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color(0xFFF5FBF7),
                  Color(0xFFFFFBF2),
                  Color(0xFFF0F6FF),
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(44),
                border: Border.all(color: const Color(0x332F6558), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F10352B),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(68, 58, 68, 52),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'salati app',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Color(0xFF10352B),
                        fontSize: 36,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2F6558),
                        fontSize: 30,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 54),
                    Text(
                      compactBody,
                      textAlign: TextAlign.center,
                      style: quranTextStyle(
                        quranFontKey,
                        TextStyle(
                          color: const Color(0xFF11231E),
                          fontSize: _shareBodyFontSize(compactBody),
                          height: 1.95,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (compactTranslation.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F8F5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x1F2F6558)),
                        ),
                        child: Text(
                          compactTranslation,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF253B35),
                            fontSize: 30,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 46),
                    const Divider(color: Color(0x332F6558), thickness: 1.5),
                    const SizedBox(height: 22),
                    Text(
                      reference,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF10352B),
                        fontSize: 32,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      salatiShareLink,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Color(0xFF2F6558),
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _shareBodyFontSize(String text) {
  final length = text.runes.length;
  if (length > 1800) return 28;
  if (length > 1200) return 32;
  if (length > 900) return 36;
  if (length > 420) return 44;
  return 54;
}

String compactQuranShareTextForImage(String value) {
  final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (trimmed.runes.length <= 2200) {
    return trimmed;
  }
  return '${String.fromCharCodes(trimmed.runes.take(2200))}...';
}
