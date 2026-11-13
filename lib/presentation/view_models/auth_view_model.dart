import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'career_booster_token';
  bool _busy = false;
  bool _initializing = true;
  bool _disposed = false;
  String? _error;
  Map<String, dynamic>? _user;
  bool get busy => _busy;
  bool get initializing => _initializing;
  bool get signedIn => _user != null;
  String? get error => _error;
  String get fullName => _user?['full_name'] as String? ?? '';

  Future<void> initialize() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/auth/me',
        );
        _user = response.data;
      }
    } catch (_) {
      _dio.options.headers.remove('Authorization');
      // Keep the saved token if offline; a later login can replace it.
    } finally {
      _initializing = false;
      _notify();
    }
  }

  Future<bool> submit({
    required bool register,
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    if (_busy) return false;
    _error = null;
    _busy = true;
    _notify();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        register ? '/api/v1/auth/register' : '/api/v1/auth/login',
        data: register
            ? {
                'full_name': fullName.trim(),
                'email': email.trim(),
                'username': username.trim(),
                'password': password,
              }
            : {'identity': username.trim(), 'password': password},
      );
      final body = response.data!;
      final token = body['access_token'] as String;
      final user = Map<String, dynamic>.from(body['user'] as Map);
      await _storage.write(key: _tokenKey, value: token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _user = user;
      return true;
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail'] : null;
      _error = detail is String
          ? detail
          : error.response?.statusCode == 422
          ? 'Check your details and try again.'
          : 'Could not reach the server. Please try again.';
      return false;
    } catch (_) {
      _error = 'Could not sign in. Please try again.';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    _dio.options.headers.remove('Authorization');
    _user = null;
    _error = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      _error = 'Could not remove the saved session.';
    }
    _notify();
  }

  void clearError() {
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
