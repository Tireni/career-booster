import 'dart:typed_data';

import '../../models/analysis_repository.dart';
import '../../models/analysis_result.dart';
import '../services/analysis_api_service.dart';

class RemoteAnalysisRepository implements AnalysisRepository {
  RemoteAnalysisRepository(this._api);
  final AnalysisApiService _api;
  @override
  Future<AnalysisResult> analyze({
    required String resume,
    required String jobUrl,
    required String jobText,
    String? filename,
    Uint8List? fileBytes,
  }) async => AnalysisResult.fromJson(
    await _api.analyze(
      resume: resume,
      jobUrl: jobUrl,
      jobText: jobText,
      filename: filename,
      fileBytes: fileBytes,
    ),
  );
}
