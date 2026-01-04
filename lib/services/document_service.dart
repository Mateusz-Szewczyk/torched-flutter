import 'package:dio/dio.dart';
import 'api_service.dart';

/// Service for document operations (upload, sections, highlights)
class DocumentService {
  final ApiService _api = ApiService();

  /// Get a single document by ID
  Future<DocumentModel> getDocument(String documentId) async {
    final response = await _api.ragGet('/documents/$documentId');
    return DocumentModel.fromJson(response.data);
  }

  /// Get all documents for the current user
  Future<List<DocumentModel>> getDocuments({String? categoryId}) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }

    final response = await _api.ragGet('/documents/', queryParameters: queryParams);
    final List<dynamic> data = response.data;
    return data.map((json) => DocumentModel.fromJson(json)).toList();
  }

  /// Upload a document
  Future<DocumentModel> uploadDocument({
    required String filePath,
    required String fileName,
    required String categoryId,
    String? description,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'category_id': categoryId,
      if (description != null) 'description': description,
    });

    final response = await _api.ragPost('/documents/upload', data: formData);
    return DocumentModel.fromJson(response.data);
  }

  /// Get sections with pagination (Lazy Loading)
  Future<SectionsResult> getSections({
    required String documentId,
    int skip = 0,
    int limit = 10,
  }) async {
    final response = await _api.ragGet(
      '/documents/$documentId/sections',
      queryParameters: {
        'skip': skip,
        'limit': limit,
      },
    );

    final data = response.data;
    final List<dynamic> sectionsJson = data['sections'] ?? [];
    final List<dynamic> highlightsJson = data['highlights'] ?? [];

    return SectionsResult(
      sections: sectionsJson.map((j) => DocumentSection.fromJson(j)).toList(),
      highlights: highlightsJson.map((j) => HighlightModel.fromJson(j)).toList(),
    );
  }

  /// Create a highlight
  Future<HighlightModel> createHighlight({
    required String documentId,
    required int sectionIndex,
    required int startOffset,
    required int endOffset,
    required String colorCode,
    String? annotation,
  }) async {
    final response = await _api.ragPost('/highlights', data: {
      'document_id': documentId,
      'section_index': sectionIndex,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'color_code': colorCode,
      if (annotation != null) 'annotation': annotation,
    });

    return HighlightModel.fromJson(response.data);
  }

  /// Update a highlight (annotation)
  Future<HighlightModel> updateHighlight({
    required String highlightId,
    String? annotation,
    String? colorCode,
  }) async {
    final response = await _api.ragPut('/highlights/$highlightId', data: {
      if (annotation != null) 'annotation': annotation,
      if (colorCode != null) 'color_code': colorCode,
    });

    return HighlightModel.fromJson(response.data);
  }

  /// Delete a highlight
  Future<void> deleteHighlight(String highlightId) async {
    await _api.ragDelete('/highlights/$highlightId');
  }

  /// Get all highlights for a document
  Future<List<HighlightModel>> getHighlights(String documentId) async {
    final response = await _api.ragGet('/documents/$documentId/highlights');
    final List<dynamic> data = response.data;
    return data.map((json) => HighlightModel.fromJson(json)).toList();
  }

  /// Get highlights by color (for filtered RAG)
  Future<List<HighlightModel>> getHighlightsByColor({
    required String documentId,
    required List<String> colors,
  }) async {
    final response = await _api.ragGet(
      '/documents/$documentId/highlights',
      queryParameters: {'colors': colors.join(',')},
    );
    final List<dynamic> data = response.data;
    return data.map((json) => HighlightModel.fromJson(json)).toList();
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    await _api.ragDelete('/documents/$documentId');
  }
}

// ============================================================================
// Models
// ============================================================================

class DocumentModel {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final String? categoryName;
  final int totalLength;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    this.categoryName,
    required this.totalLength,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: json['category_name'],
      totalLength: json['total_length'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class DocumentSection {
  final String id;
  final int sectionIndex;
  final String contentText;
  final List<TextStyle2> baseStyles;

  DocumentSection({
    required this.id,
    required this.sectionIndex,
    required this.contentText,
    required this.baseStyles,
  });

  factory DocumentSection.fromJson(Map<String, dynamic> json) {
    final List<dynamic> stylesJson = json['base_styles'] ?? [];
    return DocumentSection(
      id: json['id']?.toString() ?? '',
      sectionIndex: json['section_index'] ?? 0,
      contentText: json['content_text'] ?? '',
      baseStyles: stylesJson.map((s) => TextStyle2.fromJson(s)).toList(),
    );
  }
}

class TextStyle2 {
  final int start;
  final int end;
  final String styleName;

  TextStyle2({
    required this.start,
    required this.end,
    required this.styleName,
  });

  factory TextStyle2.fromJson(Map<String, dynamic> json) {
    return TextStyle2(
      start: json['start'] ?? 0,
      end: json['end'] ?? 0,
      styleName: json['style'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextStyle2 &&
          start == other.start &&
          end == other.end &&
          styleName == other.styleName;

  @override
  int get hashCode => Object.hash(start, end, styleName);
}

class HighlightModel {
  final String id;
  final int sectionIndex;
  final int startOffset;
  final int endOffset;
  final String colorCode;
  final String? annotation;

  HighlightModel({
    required this.id,
    required this.sectionIndex,
    required this.startOffset,
    required this.endOffset,
    required this.colorCode,
    this.annotation,
  });

  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id']?.toString() ?? '',
      sectionIndex: json['section_index'] ?? 0,
      startOffset: json['start_offset'] ?? 0,
      endOffset: json['end_offset'] ?? 0,
      colorCode: json['color_code'] ?? 'yellow',
      annotation: json['annotation'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SectionsResult {
  final List<DocumentSection> sections;
  final List<HighlightModel> highlights;

  SectionsResult({
    required this.sections,
    required this.highlights,
  });
}

