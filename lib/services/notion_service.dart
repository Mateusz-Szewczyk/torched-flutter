import 'package:dio/dio.dart';
import 'api_service.dart';

/// Notion page/database info
class NotionItem {
  final String id;
  final String title;
  final String? icon;
  final String? lastEdited;
  final String objectType; // 'page' or 'database'

  NotionItem({
    required this.id,
    required this.title,
    this.icon,
    this.lastEdited,
    required this.objectType,
  });

  factory NotionItem.fromJson(Map<String, dynamic> json) {
    return NotionItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      icon: json['icon'] as String?,
      lastEdited: json['last_edited'] as String?,
      objectType: json['object_type'] as String? ?? 'page',
    );
  }
}

/// Notion connection status
class NotionConnectionStatus {
  final bool connected;
  final String? workspaceName;
  final DateTime? connectedAt;
  final int importCount;
  final int importLimit;

  NotionConnectionStatus({
    required this.connected,
    this.workspaceName,
    this.connectedAt,
    this.importCount = 0,
    this.importLimit = 1,
  });

  factory NotionConnectionStatus.fromJson(Map<String, dynamic> json) {
    return NotionConnectionStatus(
      connected: json['connected'] as bool? ?? false,
      workspaceName: json['workspace_name'] as String?,
      connectedAt: json['connected_at'] != null
          ? DateTime.tryParse(json['connected_at'] as String)
          : null,
      importCount: json['import_count'] as int? ?? 0,
      importLimit: json['import_limit'] as int? ?? 1,
    );
  }

  int get remainingImports => importLimit - importCount;
  bool get canImport => remainingImports > 0;
}

/// Import response
class NotionImportResult {
  final bool success;
  final String? documentId;
  final String message;

  NotionImportResult({
    required this.success,
    this.documentId,
    required this.message,
  });

  factory NotionImportResult.fromJson(Map<String, dynamic> json) {
    return NotionImportResult(
      success: json['success'] as bool? ?? false,
      documentId: json['document_id'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Sync response
class NotionSyncResult {
  final bool success;
  final String message;
  final bool updated;

  NotionSyncResult({
    required this.success,
    required this.message,
    this.updated = false,
  });

  factory NotionSyncResult.fromJson(Map<String, dynamic> json) {
    return NotionSyncResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      updated: json['updated'] as bool? ?? false,
    );
  }
}

/// Service for Notion integration API calls
class NotionService {
  final ApiService _api = ApiService();

  /// Get Notion connection status
  Future<NotionConnectionStatus> getConnectionStatus() async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>('/notion/status');
      if (response.statusCode == 200 && response.data != null) {
        return NotionConnectionStatus.fromJson(response.data!);
      }
      return NotionConnectionStatus(connected: false);
    } catch (e) {
      rethrow;
    }
  }

  /// Get OAuth authorization URL
  Future<String> getAuthorizationUrl() async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>('/notion/auth/authorize');
      if (response.statusCode == 200 && response.data != null) {
        return response.data!['authorization_url'] as String? ?? '';
      }
      throw Exception('Failed to get authorization URL');
    } catch (e) {
      rethrow;
    }
  }

  /// Disconnect Notion account
  Future<bool> disconnect() async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>('/notion/disconnect');
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// List accessible pages and databases
  Future<({List<NotionItem> pages, List<NotionItem> databases})> listContent() async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>('/notion/pages');
      if (response.statusCode == 200 && response.data != null) {
        final pagesJson = response.data!['pages'] as List<dynamic>? ?? [];
        final dbsJson = response.data!['databases'] as List<dynamic>? ?? [];
        
        return (
          pages: pagesJson.map((j) => NotionItem.fromJson(j as Map<String, dynamic>)).toList(),
          databases: dbsJson.map((j) => NotionItem.fromJson(j as Map<String, dynamic>)).toList(),
        );
      }
      return (pages: <NotionItem>[], databases: <NotionItem>[]);
    } catch (e) {
      rethrow;
    }
  }

  /// Import a Notion page
  Future<NotionImportResult> importPage({
    required String pageId,
    required String categoryId,
    String? titleOverride,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/notion/import',
        data: {
          'page_id': pageId,
          'category_id': categoryId,
          if (titleOverride != null) 'title_override': titleOverride,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return NotionImportResult.fromJson(response.data!);
      }
      return NotionImportResult(success: false, message: 'Import failed');
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final detail = e.response!.data['detail'] as String?;
        return NotionImportResult(success: false, message: detail ?? 'Import failed');
      }
      rethrow;
    }
  }

  /// Manually sync a Notion document
  Future<NotionSyncResult> syncDocument(String documentId) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/notion/sync/$documentId',
      );
      if (response.statusCode == 200 && response.data != null) {
        return NotionSyncResult.fromJson(response.data!);
      }
      return NotionSyncResult(success: false, message: 'Sync failed');
    } catch (e) {
      rethrow;
    }
  }
}
