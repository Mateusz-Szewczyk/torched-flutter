import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/constants.dart';
import 'storage_service.dart';

// API Service - handles all HTTP requests
// Equivalent to fetchJson.ts and axios usage in React app

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final _cookieJar = CookieJar();
  final _storage = StorageService();

  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (!kIsWeb) {
      _dio.interceptors.add(CookieManager(_cookieJar));
    }

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add JWT token from storage if available
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Cookie'] = 'TorchED_auth=$token';
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
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  String? _extractToken(String cookie) {
    final match = RegExp(r'TorchED_auth=([^;]+)').firstMatch(cookie);
    return match?.group(1);
  }

  // ============================================================================
  // GENERIC HTTP METHODS
  // ============================================================================

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get<T>(
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
    return await _dio.post<T>(
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
    return await _dio.put<T>(
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
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ============================================================================
  // FILE UPLOAD
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

    return await _dio.post<T>(
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

