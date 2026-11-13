import 'dart:typed_data';

import 'package:dio/dio.dart';

class AnalysisApiService {
  AnalysisApiService(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> analyze({
    required String resume,
    required String jobUrl,
    required String jobText,
    String? filename,
    Uint8List? fileBytes,
  }) async {
    final data = FormData.fromMap({
      'resume_text': resume,
      'job_url': jobUrl,
      'job_text': jobText,
      if (fileBytes != null && filename != null)
        'resume_file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/analyze',
        data: data,
      );
      if (response.data == null) throw const FormatException('Empty response');
      return response.data!;
    } on DioException catch (error) {
      final body = error.response?.data;
      final detail = body is Map ? body['detail'] : null;
      if (detail is String && detail.isNotEmpty) {
        throw AnalysisApiException(detail);
      }
      throw const AnalysisApiException(
        'Could not reach the analysis service. Check the server and try again.',
      );
    }
  }
}

class AnalysisApiException implements Exception {
  const AnalysisApiException(this.message);
  final String message;
}
