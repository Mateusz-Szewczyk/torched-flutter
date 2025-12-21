import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/constants.dart';
import 'storage_service.dart';

// API Service - handles all HTTP requests
// Equivalent to fetchJson.ts and axios usage in React app
//
// Two separate APIs:
// - Flask API (localhost:14440) - User management, auth
// - RAG API (localhost:8043) - Chat, flashcards, exams, files

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _flaskDio;  // For auth/user management
  late final Dio _ragDio;    // For chat, flashcards, exams, files
  final _cookieJar = CookieJar();
  final _storage = StorageService();

  /// Get the RAG API base URL for streaming requests
  String get ragBaseUrl => AppConfig.ragApiUrl;

  void init() {
    // Initialize Flask API client (auth, user management)
    _flaskDio = _createDio(AppConfig.flaskApiUrl);

    // Initialize RAG API client (chat, flashcards, exams, files)
    _ragDio = _createDio(AppConfig.ragApiUrl);
  }

  Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
        // Enable credentials for cross-origin requests (cookies)
        extra: {'withCredentials': true},
      ),
    );

    // Configure for web platform to send credentials
    if (kIsWeb) {
      dio.options.extra['withCredentials'] = true;
    } else {
      dio.interceptors.add(CookieManager(_cookieJar));
    }

    // Add auth interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // For web, use Authorization header with Bearer token
          // (Cookie header is forbidden in browsers for CORS requests)
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Save JWT token from Set-Cookie header
          final setCookie = response.headers['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            final cookie = setCookie.first;
            if (cookie.contains('TorchED_auth=')) {
              final token = _extractToken(cookie);
              if (token != null) {
                _storage.saveToken(token);
              }
            }
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          // Handle auth errors
          if (error.response?.statusCode == 401) {
            _storage.clearUserData();
          }
          return handler.next(error);
        },
      ),
    );

    // Add logging in debug mode
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  }

  String? _extractToken(String cookie) {
    final match = RegExp(r'TorchED_auth=([^;]+)').firstMatch(cookie);
    return match?.group(1);
  }

  // ============================================================================
  // API SELECTION HELPER
  // ============================================================================

  /// Determines which API to use based on the endpoint path
  Dio _getDioForPath(String path) {
    // Flask API endpoints (auth-related)
    if (path.startsWith('/auth') ||
        path.startsWith(AppConfig.authEndpoint)) {
      return _flaskDio;
    }
    // RAG API endpoints (everything else)
    return _ragDio;
  }

  // ============================================================================
  // GENERIC HTTP METHODS (auto-select API based on path)
  // ============================================================================

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _getDioForPath(path).get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _getDioForPath(path).post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _getDioForPath(path).put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _getDioForPath(path).delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ============================================================================
  // EXPLICIT API METHODS (for cases where you want to specify which API)
  // ============================================================================

  /// Make a request to the Flask API (auth, user management)
  Future<Response<T>> flaskGet<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _flaskDio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> flaskPost<T>(String path, {dynamic data}) async {
    return await _flaskDio.post<T>(path, data: data);
  }

  /// Make a request to the RAG API (chat, flashcards, exams, files)
  Future<Response<T>> ragGet<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _ragDio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> ragPost<T>(String path, {dynamic data}) async {
    return await _ragDio.post<T>(path, data: data);
  }

  Future<Response<T>> ragPut<T>(String path, {dynamic data}) async {
    return await _ragDio.put<T>(path, data: data);
  }

  Future<Response<T>> ragPatch<T>(String path, {dynamic data}) async {
    return await _ragDio.patch<T>(path, data: data);
  }

  Future<Response<T>> ragDelete<T>(String path, {dynamic data}) async {
    return await _ragDio.delete<T>(path, data: data);
  }

  // ============================================================================
  // FILE UPLOAD (RAG API)
  // ============================================================================

  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      ...?data,
    });

    return await _ragDio.post<T>(
      path,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
      onSendProgress: onSendProgress,
    );
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

  String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            return ErrorMessages.authError;
          } else if (statusCode == 403) {
            return ErrorMessages.accessDenied;
          }
          return error.response?.data?['message'] ??
                 error.response?.data?['detail'] ??
                 ErrorMessages.unknownError;
        case DioExceptionType.cancel:
          return 'Request cancelled.';
        case DioExceptionType.unknown:
          return ErrorMessages.networkError;
        default:
          return ErrorMessages.unknownError;
      }
    }
    return error.toString();
  }
}

