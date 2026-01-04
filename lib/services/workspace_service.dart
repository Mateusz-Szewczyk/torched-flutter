import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';

class WorkspaceService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  /// Get all workspaces for current user
  Future<List<WorkspaceModel>> getWorkspaces() async {
    try {
      final response = await _apiService.ragGet('/workspaces/');
      return (response.data as List)
          .map((e) => WorkspaceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching workspaces: $e');
      rethrow;
    }
  }

  /// Create a new workspace
  Future<WorkspaceModel> createWorkspace({
    required String name,
    required String description,
    required List<String> categoryIds,
  }) async {
    try {
      final response = await _apiService.ragPost(
        '/workspaces/',
        data: {
          'name': name,
          'description': description,
          'category_ids': categoryIds,
        },
      );
      return WorkspaceModel.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error creating workspace: $e');
      rethrow;
    }
  }

  /// Update an existing workspace
  Future<WorkspaceModel> updateWorkspace({
    required String workspaceId,
    required String name,
    required String description,
    required List<String> categoryIds,
  }) async {
    try {
      final response = await _apiService.ragPut(
        '/workspaces/$workspaceId',
        data: {
          'name': name,
          'description': description,
          'category_ids': categoryIds,
        },
      );
      return WorkspaceModel.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error updating workspace: $e');
      rethrow;
    }
  }

  /// Delete a workspace
  Future<void> deleteWorkspace(String workspaceId) async {
    try {
      await _apiService.ragDelete('/workspaces/$workspaceId');
    } catch (e) {
      print('[WorkspaceService] Error deleting workspace: $e');
      rethrow;
    }
  }

  /// Get workspace by ID
  Future<WorkspaceModel> getWorkspace(String workspaceId) async {
    try {
      final response = await _apiService.ragGet('/workspaces/$workspaceId');
      return WorkspaceModel.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error fetching workspace: $e');
      rethrow;
    }
  }

  /// Get documents in workspace
  Future<List<WorkspaceDocumentBrief>> getWorkspaceDocuments({
    required String workspaceId,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.ragGet(
        '/workspaces/$workspaceId/documents',
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((e) => WorkspaceDocumentBrief.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching workspace documents: $e');
      rethrow;
    }
  }

  // =============================================================================
  // CONVERSATION MANAGEMENT
  // =============================================================================

  /// Get conversations for a specific workspace
  Future<List<WorkspaceConversation>> getWorkspaceConversations(String workspaceId) async {
    try {
      final response = await _apiService.ragGet(
        '/chats/',
        queryParameters: {'workspace_id': workspaceId},
      );
      return (response.data as List)
          .map((e) => WorkspaceConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching workspace conversations: $e');
      rethrow;
    }
  }

  /// Create a new conversation in workspace
  Future<WorkspaceConversation> createWorkspaceConversation(String workspaceId) async {
    try {
      final response = await _apiService.ragPost(
        '/chats/',
        data: {'workspace_id': workspaceId},
      );
      return WorkspaceConversation.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error creating workspace conversation: $e');
      rethrow;
    }
  }

  /// Get messages for a conversation
  Future<List<WorkspaceMessage>> getConversationMessages(int conversationId) async {
    try {
      final response = await _apiService.ragGet('/chats/$conversationId/messages/');
      return (response.data as List)
          .map((e) => WorkspaceMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching messages: $e');
      rethrow;
    }
  }

  /// Save a message to conversation
  Future<WorkspaceMessage> saveMessage({
    required int conversationId,
    required String sender,
    required String text,
    String? metadata,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'sender': sender,
        'text': text,
      };

      // Include metadata if provided
      if (metadata != null && metadata.isNotEmpty) {
        data['metadata'] = metadata;
      }

      final response = await _apiService.ragPost(
        '/chats/$conversationId/messages/',
        data: data,
      );
      return WorkspaceMessage.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error saving message: $e');
      rethrow;
    }
  }

  // =============================================================================
  // HIGHLIGHT CONTEXT FOR CHAT
  // =============================================================================

  /// Get context for chat based on selected highlight colors
  Future<ChatContext> getChatContext({
    required String query,
    String? documentId,
    List<String>? filterColors,
  }) async {
    try {
      final response = await _apiService.ragPost(
        '/workspace/chat/context',
        data: {
          'query': query,
          if (documentId != null) 'document_id': documentId,
          if (filterColors != null && filterColors.isNotEmpty)
            'filter_colors': filterColors,
        },
      );
      return ChatContext.fromJson(response.data);
    } catch (e) {
      // If context endpoint fails, return empty context gracefully
      print('[WorkspaceService] Error getting chat context: $e - continuing without highlight context');
      return ChatContext(
        contextText: '',
        contextSource: 'none',
        highlightsUsed: [],
        documentsSearched: [],
      );
    }
  }

  /// Get available highlight colors
  Future<Map<String, HighlightColorInfo>> getHighlightColors() async {
    try {
      final response = await _apiService.ragGet('/workspace/chat/colors');
      final data = response.data as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(
        key,
        HighlightColorInfo.fromJson(value as Map<String, dynamic>),
      ));
    } catch (e) {
      print('[WorkspaceService] Error fetching colors: $e');
      // Return default colors
      return {
        'red': HighlightColorInfo(name: 'Red', hex: '#ef4444', description: 'Important'),
        'yellow': HighlightColorInfo(name: 'Yellow', hex: '#eab308', description: 'Key Concepts'),
        'green': HighlightColorInfo(name: 'Green', hex: '#22c55e', description: 'Understood'),
        'blue': HighlightColorInfo(name: 'Blue', hex: '#3b82f6', description: 'Definitions'),
        'purple': HighlightColorInfo(name: 'Purple', hex: '#a855f7', description: 'Examples'),
      };
    }
  }

  /// Get document metadata
  Future<DocumentMetadata> getDocument(String documentId) async {
    try {
      final response = await _apiService.ragGet('/workspace/documents/$documentId');
      return DocumentMetadata.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error fetching document: $e');
      rethrow;
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    try {
      await _apiService.ragDelete('/workspace/documents/$documentId');
    } catch (e) {
      print('[WorkspaceService] Error deleting document: $e');
      rethrow;
    }
  }

  /// Get document sections with lazy loading
  Future<SectionsWithHighlights> getSections(
    String documentId, {
    required int startSection,
    required int endSection,
  }) async {
    try {
      final response = await _apiService.ragGet(
        '/workspace/documents/$documentId/sections',
        queryParameters: {
          'start_section': startSection,
          'end_section': endSection,
        },
      );
      return SectionsWithHighlights.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error fetching sections: $e');
      rethrow;
    }
  }

  /// Create a highlight
  Future<Highlight> createHighlight({
    required String documentId,
    required String sectionId,
    required int startOffset,
    required int endOffset,
    required String colorCode,
    String? annotationText,
  }) async {
    try {
      final response = await _apiService.ragPost(
        '/workspace/highlights',
        data: {
          'document_id': documentId,
          'section_id': sectionId,
          'start_offset': startOffset,
          'end_offset': endOffset,
          'color_code': colorCode,
          'annotation_text': annotationText,
        },
      );
      return Highlight.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error creating highlight: $e');
      rethrow;
    }
  }

  /// Update a highlight
  Future<Highlight> updateHighlight(
    String highlightId, {
    String? colorCode,
    String? annotationText,
  }) async {
    try {
      final response = await _apiService.ragPut(
        '/workspace/highlights/$highlightId',
        data: {
          if (colorCode != null) 'color_code': colorCode,
          if (annotationText != null) 'annotation_text': annotationText,
        },
      );
      return Highlight.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error updating highlight: $e');
      rethrow;
    }
  }

  /// Delete a highlight
  Future<void> deleteHighlight(String highlightId) async {
    try {
      await _apiService.ragDelete('/workspace/highlights/$highlightId');
    } catch (e) {
      print('[WorkspaceService] Error deleting highlight: $e');
      rethrow;
    }
  }

  /// Send chat query with optional color filter
  Future<String> sendChatQuery({
    required String query,
    required String workspaceId,
    List<String>? filterColors,
  }) async {
    try {
      final response = await _apiService.ragPost(
        '/workspace/chat',
        data: {
          'query': query,
          'workspace_id': workspaceId,
          if (filterColors != null && filterColors.isNotEmpty)
            'filter_colors': filterColors,
        },
      );
      return response.data['response'] as String;
    } catch (e) {
      print('[WorkspaceService] Error sending chat query: $e');
      rethrow;
    }
  }

  // =============================================================================
  // SEARCH & PAGE NAVIGATION
  // =============================================================================

  /// Search for text within a document
  Future<SearchResponse> searchDocument({
    required String documentId,
    required String query,
    int contextSections = 1,
  }) async {
    try {
      final response = await _apiService.ragGet(
        '/workspace/documents/$documentId/search',
        queryParameters: {
          'query': query,
          'context_sections': contextSections,
        },
      );
      return SearchResponse.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error searching document: $e');
      rethrow;
    }
  }

  /// Get list of pages in a document
  Future<PagesResponse> getDocumentPages(String documentId) async {
    try {
      final response = await _apiService.ragGet(
        '/workspace/documents/$documentId/pages',
      );
      return PagesResponse.fromJson(response.data);
    } catch (e) {
      print('[WorkspaceService] Error fetching document pages: $e');
      rethrow;
    }
  }

  /// Get sections for a specific page
  Future<SectionsWithHighlights> getSectionsByPage({
    required String documentId,
    required int pageNumber,
  }) async {
    try {
      final response = await _apiService.ragGet(
        '/workspace/documents/$documentId/sections/by-page/$pageNumber',
      );

      // Convert the response to SectionsWithHighlights format
      final sections = (response.data['sections'] as List)
          .map((s) => DocumentSection.fromJson(s as Map<String, dynamic>))
          .toList();
      final highlights = (response.data['highlights'] as List)
          .map((h) => Highlight.fromJson(h as Map<String, dynamic>))
          .toList();

      return SectionsWithHighlights(
        sections: sections,
        highlights: highlights,
        totalSections: response.data['section_count'] as int? ?? sections.length,
        hasMore: false, // Page-based fetch doesn't use hasMore
      );
    } catch (e) {
      print('[WorkspaceService] Error fetching sections by page: $e');
      rethrow;
    }
  }

  // =============================================================================
  // DOCUMENT IMAGES
  // =============================================================================

  /// Get all images for a document
  Future<List<DocumentImage>> getDocumentImages(String documentId) async {
    try {
      final response = await _apiService.ragGet(
        '/files/documents/$documentId/images',
      );
      return (response.data as List)
          .map((e) => DocumentImage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching document images: $e');
      return []; // Return empty list on error, images are optional
    }
  }

  /// Get images for a specific page
  Future<List<DocumentImage>> getPageImages({
    required String documentId,
    required int pageNumber,
  }) async {
    try {
      final response = await _apiService.ragGet(
        '/files/documents/$documentId/images/by-page/$pageNumber',
      );
      return (response.data as List)
          .map((e) => DocumentImage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[WorkspaceService] Error fetching page images: $e');
      return []; // Return empty list on error
    }
  }

  /// Get full image URL from relative path with auth token
  Future<String> getImageUrl(String imageId) async {
    final token = await _storageService.getToken();
    final baseUrl = _apiService.getRagBaseUrl() + '/files/images/$imageId';
    if (token != null && token.isNotEmpty) {
      return '$baseUrl?token=${Uri.encodeQueryComponent(token)}';
    }
    return baseUrl;
  }

  /// Get image URL synchronously (cached token version)
  /// Use this for Image.network widgets where async is not convenient
  String getImageUrlSync(String imageId, {String? cachedToken}) {
    final baseUrl = _apiService.getRagBaseUrl() + '/files/images/$imageId';
    if (cachedToken != null && cachedToken.isNotEmpty) {
      final url = '$baseUrl?token=${Uri.encodeQueryComponent(cachedToken)}';
      debugPrint('[WorkspaceService] Image URL with token (${cachedToken.length} chars)');
      return url;
    }
    debugPrint('[WorkspaceService] Image URL WITHOUT token - auth will fail!');
    return baseUrl;
  }
}

// =============================================================================
// MODELS
// =============================================================================

/// Search result models
class SearchResponse {
  final List<SearchResult> results;
  final int totalMatches;
  final int sectionsWithMatches;

  SearchResponse({
    required this.results,
    required this.totalMatches,
    required this.sectionsWithMatches,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results: (json['results'] as List?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalMatches: json['total_matches'] as int? ?? 0,
      sectionsWithMatches: json['sections_with_matches'] as int? ?? 0,
    );
  }
}

class SearchResult {
  final String sectionId;
  final int sectionIndex;
  final int pageNumber;
  final List<SearchMatch> matches;
  final int matchCount;
  final List<int> contextSectionIndices;
  final String preview;

  SearchResult({
    required this.sectionId,
    required this.sectionIndex,
    required this.pageNumber,
    required this.matches,
    required this.matchCount,
    required this.contextSectionIndices,
    required this.preview,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      sectionId: json['section_id'] as String,
      sectionIndex: json['section_index'] as int,
      pageNumber: json['page_number'] as int? ?? 1,
      matches: (json['matches'] as List?)
              ?.map((e) => SearchMatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      matchCount: json['match_count'] as int? ?? 0,
      contextSectionIndices: (json['context_section_indices'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      preview: json['preview'] as String? ?? '',
    );
  }
}

class SearchMatch {
  final int startOffset;
  final int endOffset;
  final String matchText;

  SearchMatch({
    required this.startOffset,
    required this.endOffset,
    required this.matchText,
  });

  factory SearchMatch.fromJson(Map<String, dynamic> json) {
    return SearchMatch(
      startOffset: json['start_offset'] as int,
      endOffset: json['end_offset'] as int,
      matchText: json['match_text'] as String? ?? '',
    );
  }
}

class PagesResponse {
  final List<PageInfo> pages;
  final int totalPages;
  final int totalSections;

  PagesResponse({
    required this.pages,
    required this.totalPages,
    required this.totalSections,
  });

  factory PagesResponse.fromJson(Map<String, dynamic> json) {
    return PagesResponse(
      pages: (json['pages'] as List?)
              ?.map((e) => PageInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalPages: json['total_pages'] as int? ?? 0,
      totalSections: json['total_sections'] as int? ?? 0,
    );
  }
}

class PageInfo {
  final int pageNumber;
  final int startSectionIndex;
  final int endSectionIndex;
  final int sectionCount;
  final List<String> sectionIds;

  PageInfo({
    required this.pageNumber,
    required this.startSectionIndex,
    required this.endSectionIndex,
    required this.sectionCount,
    required this.sectionIds,
  });

  factory PageInfo.fromJson(Map<String, dynamic> json) {
    return PageInfo(
      pageNumber: json['page_number'] as int,
      startSectionIndex: json['start_section_index'] as int,
      endSectionIndex: json['end_section_index'] as int,
      sectionCount: json['section_count'] as int? ?? 0,
      sectionIds: (json['section_ids'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class WorkspaceModel {
  final String id;
  final String name;
  final String? description;
  final List<CategoryBrief> categories;
  final String createdAt;

  WorkspaceModel({
    required this.id,
    required this.name,
    this.description,
    required this.categories,
    required this.createdAt,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categories: (json['categories'] as List?)
              ?.map((e) => CategoryBrief.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }
}

class CategoryBrief {
  final String id;
  final String name;

  CategoryBrief({
    required this.id,
    required this.name,
  });

  factory CategoryBrief.fromJson(Map<String, dynamic> json) {
    return CategoryBrief(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class WorkspaceDocumentBrief {
  final String id;
  final String title;
  final String? categoryName;
  final String createdAt;

  WorkspaceDocumentBrief({
    required this.id,
    required this.title,
    this.categoryName,
    required this.createdAt,
  });

  factory WorkspaceDocumentBrief.fromJson(Map<String, dynamic> json) {
    return WorkspaceDocumentBrief(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryName: json['category_name'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

class DocumentMetadata {
  final String id;
  final String title;
  final String? originalFilename;
  final String? fileType;
  final int totalLength;
  final int totalSections;
  final String createdAt;

  DocumentMetadata({
    required this.id,
    required this.title,
    this.originalFilename,
    this.fileType,
    required this.totalLength,
    required this.totalSections,
    required this.createdAt,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      originalFilename: json['original_filename'] as String?,
      fileType: json['file_type'] as String?,
      totalLength: json['total_length'] as int,
      totalSections: json['total_sections'] as int,
      createdAt: json['created_at'] as String,
    );
  }
}

class DocumentSection {
  final String id;
  final int sectionIndex;
  final String contentText;
  final List<BaseStyle> baseStyles;
  final Map<String, dynamic> sectionMetadata;
  final int charStart;
  final int charEnd;

  DocumentSection({
    required this.id,
    required this.sectionIndex,
    required this.contentText,
    required this.baseStyles,
    required this.sectionMetadata,
    required this.charStart,
    required this.charEnd,
  });

  factory DocumentSection.fromJson(Map<String, dynamic> json) {
    return DocumentSection(
      id: json['id'] as String,
      sectionIndex: json['section_index'] as int,
      contentText: json['content_text'] as String,
      baseStyles: (json['base_styles'] as List?)
              ?.map((e) => BaseStyle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sectionMetadata: json['section_metadata'] as Map<String, dynamic>? ?? {},
      charStart: json['char_start'] as int,
      charEnd: json['char_end'] as int,
    );
  }
}

class BaseStyle {
  final int start;
  final int end;
  final String style;

  BaseStyle({
    required this.start,
    required this.end,
    required this.style,
  });

  factory BaseStyle.fromJson(Map<String, dynamic> json) {
    return BaseStyle(
      start: json['start'] as int,
      end: json['end'] as int,
      style: json['style'] as String,
    );
  }
}

class Highlight {
  final String id;
  final String documentId;
  final String sectionId;
  final int startOffset;
  final int endOffset;
  final String colorCode;
  final String? annotationText;
  final String createdAt;

  Highlight({
    required this.id,
    required this.documentId,
    required this.sectionId,
    required this.startOffset,
    required this.endOffset,
    required this.colorCode,
    this.annotationText,
    required this.createdAt,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      sectionId: json['section_id'] as String,
      startOffset: json['start_offset'] as int,
      endOffset: json['end_offset'] as int,
      colorCode: json['color_code'] as String,
      annotationText: json['annotation_text'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

class SectionsWithHighlights {
  final List<DocumentSection> sections;
  final List<Highlight> highlights;
  final int totalSections;
  final bool hasMore;

  SectionsWithHighlights({
    required this.sections,
    required this.highlights,
    required this.totalSections,
    required this.hasMore,
  });

  factory SectionsWithHighlights.fromJson(Map<String, dynamic> json) {
    return SectionsWithHighlights(
      sections: (json['sections'] as List)
          .map((e) => DocumentSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      highlights: (json['highlights'] as List)
          .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSections: json['total_sections'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

// =============================================================================
// CONVERSATION MODELS
// =============================================================================

class WorkspaceConversation {
  final int id;
  final int userId;
  final String? title;
  final String? workspaceId;
  final String createdAt;

  WorkspaceConversation({
    required this.id,
    required this.userId,
    this.title,
    this.workspaceId,
    required this.createdAt,
  });

  factory WorkspaceConversation.fromJson(Map<String, dynamic> json) {
    return WorkspaceConversation(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String?,
      workspaceId: json['workspace_id'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  /// Creates a copy of this object with the given fields replaced with the new values.
  WorkspaceConversation copyWith({
    int? id,
    int? userId,
    String? title,
    String? workspaceId,
    String? createdAt,
  }) {
    return WorkspaceConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      workspaceId: workspaceId ?? this.workspaceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkspaceMessage {
  final int id;
  final int conversationId;
  final String sender;
  final String text;
  final String createdAt;
  final String? metadata;

  WorkspaceMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.metadata,
  });

  factory WorkspaceMessage.fromJson(Map<String, dynamic> json) {
    return WorkspaceMessage(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      sender: json['sender'] as String,
      text: json['text'] as String,
      createdAt: json['created_at'] as String,
      metadata: json['metadata'] as String?,
    );
  }
}

// =============================================================================
// CHAT CONTEXT MODELS
// =============================================================================

class ChatContext {
  final String contextText;
  final String contextSource;
  final List<HighlightUsed> highlightsUsed;
  final List<String> documentsSearched;
  final List<String>? colorsFiltered;
  final int? totalHighlights;
  final String? message;

  ChatContext({
    required this.contextText,
    required this.contextSource,
    required this.highlightsUsed,
    required this.documentsSearched,
    this.colorsFiltered,
    this.totalHighlights,
    this.message,
  });

  factory ChatContext.fromJson(Map<String, dynamic> json) {
    return ChatContext(
      contextText: json['context_text'] as String? ?? '',
      contextSource: json['context_source'] as String? ?? 'unknown',
      highlightsUsed: (json['highlights_used'] as List?)
              ?.map((e) => HighlightUsed.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      documentsSearched: (json['documents_searched'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      colorsFiltered: (json['colors_filtered'] as List?)
              ?.map((e) => e as String)
              .toList(),
      totalHighlights: json['total_highlights'] as int?,
      message: json['message'] as String?,
    );
  }
}

class HighlightUsed {
  final String id;
  final String color;
  final String textPreview;
  final String? annotation;
  final String documentTitle;

  HighlightUsed({
    required this.id,
    required this.color,
    required this.textPreview,
    this.annotation,
    required this.documentTitle,
  });

  factory HighlightUsed.fromJson(Map<String, dynamic> json) {
    return HighlightUsed(
      id: json['id'] as String,
      color: json['color'] as String,
      textPreview: json['text_preview'] as String,
      annotation: json['annotation'] as String?,
      documentTitle: json['document_title'] as String,
    );
  }
}

class HighlightColorInfo {
  final String name;
  final String hex;
  final String description;

  HighlightColorInfo({
    required this.name,
    required this.hex,
    required this.description,
  });

  factory HighlightColorInfo.fromJson(Map<String, dynamic> json) {
    return HighlightColorInfo(
      name: json['name'] as String,
      hex: json['hex'] as String,
      description: json['description'] as String,
    );
  }
}

// =============================================================================
// DOCUMENT IMAGE MODELS
// =============================================================================

class DocumentImage {
  final String id;
  final int pageNumber;
  final int imageIndex;
  final String imageUrl;
  final String imageType;
  final int? width;
  final int? height;
  final double? xPosition;
  final double? yPosition;
  final String? altText;

  DocumentImage({
    required this.id,
    required this.pageNumber,
    required this.imageIndex,
    required this.imageUrl,
    required this.imageType,
    this.width,
    this.height,
    this.xPosition,
    this.yPosition,
    this.altText,
  });

  factory DocumentImage.fromJson(Map<String, dynamic> json) {
    return DocumentImage(
      id: json['id'] as String,
      pageNumber: json['page_number'] as int,
      imageIndex: json['image_index'] as int,
      imageUrl: json['image_url'] as String,
      imageType: json['image_type'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      xPosition: (json['x_position'] as num?)?.toDouble(),
      yPosition: (json['y_position'] as num?)?.toDouble(),
      altText: json['alt_text'] as String?,
    );
  }
}
