import 'package:flutter/foundation.dart';

import '../../data/services/analysis_api_service.dart';
import '../../models/analysis_repository.dart';
import '../../models/analysis_result.dart';

class BoosterViewModel extends ChangeNotifier {
  BoosterViewModel(this._repository);
  final AnalysisRepository _repository;
  AnalysisResult? _result;
  String? _error;
  bool _busy = false;
  bool _disposed = false;
  AnalysisResult? get result => _result;
  String? get error => _error;
  bool get busy => _busy;

  Future<bool> analyze({
    required String resume,
    required String jobUrl,
    required String jobText,
    String? filename,
    Uint8List? fileBytes,
  }) async {
    if (_busy) return false;
    _result = null;
    final text = resume.trim(), url = jobUrl.trim(), job = jobText.trim();
    if (fileBytes == null && text.length < 30) {
      _error = 'Add at least 30 characters of resume text or upload a file.';
    } else if (fileBytes != null && fileBytes.length > 2 * 1024 * 1024) {
      _error = 'Choose a file smaller than 2 MB.';
    } else if (url.isEmpty && job.length < 80) {
      _error = 'Add a job URL or at least 80 characters of job description.';
    } else if (url.isNotEmpty && job.isNotEmpty) {
      _error = 'Use a job URL or paste a job description, not both.';
    } else {
      _error = null;
    }
    if (_error != null) {
      _notify();
      return false;
    }
    _busy = true;
    _result = null;
    _notify();
    try {
      _result = await _repository.analyze(
        resume: fileBytes == null ? text : '',
        jobUrl: url,
        jobText: job,
        filename: filename,
        fileBytes: fileBytes,
      );
      return true;
    } on AnalysisApiException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = 'The analysis could not be completed. Please try again.';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clear() {
    if (_busy) return;
    _result = null;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
