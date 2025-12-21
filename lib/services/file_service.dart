import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../config/constants.dart';

/// Model for uploaded file from backend
class UploadedFileInfo {
  final int id;
  final String name;
  final String description;
  final String category;
  final String createdAt;

  UploadedFileInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.createdAt,
  });

  factory UploadedFileInfo.fromJson(Map<String, dynamic> json) {
    return UploadedFileInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Service for file management operations
class FileService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  /// Fetch list of uploaded files
  Future<List<UploadedFileInfo>> fetchFiles() async {
    try {
      final response = await _api.ragGet<List<dynamic>>('/files/list/');

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) => UploadedFileInfo.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a file with description and category
  /// Returns list of uploaded files from response
  Future<List<UploadedFileInfo>> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    required String description,
    required String category,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file_description': description,
        'category': category,
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      // Create Dio instance for this request with progress support
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.ragApiUrl,
        connectTimeout: const Duration(minutes: 5), // Longer timeout for uploads
        receiveTimeout: const Duration(minutes: 5),
      ));

      // Add auth header
      final token = await _storage.getToken();
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.post<Map<String, dynamic>>(
        '/files/upload/',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200 && response.data != null) {
        final uploadedFiles = response.data!['uploaded_files'] as List<dynamic>?;
        if (uploadedFiles != null) {
          return uploadedFiles
              .map((json) => UploadedFileInfo.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a file by name
  Future<bool> deleteFile(String fileName) async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/files/delete-file/',
        data: {'file_name': fileName},
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}

