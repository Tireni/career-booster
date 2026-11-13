import 'dart:typed_data';

import 'analysis_result.dart';

abstract interface class AnalysisRepository {
  Future<AnalysisResult> analyze({
    required String resume,
    required String jobUrl,
    required String jobText,
    String? filename,
    Uint8List? fileBytes,
  });
}
