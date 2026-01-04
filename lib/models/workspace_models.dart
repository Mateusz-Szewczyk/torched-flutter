import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_models.freezed.dart';
part 'workspace_models.g.dart';

// =============================================================================
// WORKSPACE DOCUMENT MODELS
// =============================================================================

@freezed
class WorkspaceDocument with _$WorkspaceDocument {
  const factory WorkspaceDocument({
    required String id,
    required String title,
    String? originalFilename,
    String? fileType,
    @Default(0) int totalLength,
    @Default(0) int totalSections,
    required String createdAt,
  }) = _WorkspaceDocument;

  factory WorkspaceDocument.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceDocumentFromJson(json);
}

@freezed
class DocumentSection with _$DocumentSection {
  const factory DocumentSection({
    required String id,
    required int sectionIndex,
    required String contentText,
    @Default([]) List<TextStyleSpan> baseStyles,
    @Default({}) Map<String, dynamic> sectionMetadata,
    @Default(0) int charStart,
    @Default(0) int charEnd,
  }) = _DocumentSection;

  factory DocumentSection.fromJson(Map<String, dynamic> json) =>
      _$DocumentSectionFromJson(json);
}

@freezed
class TextStyleSpan with _$TextStyleSpan {
  const factory TextStyleSpan({
    required int start,
    required int end,
    required String style, // 'bold', 'italic', 'bold_italic'
  }) = _TextStyleSpan;

  factory TextStyleSpan.fromJson(Map<String, dynamic> json) =>
      _$TextStyleSpanFromJson(json);
}

// =============================================================================
// HIGHLIGHT MODELS
// =============================================================================

@freezed
class UserHighlight with _$UserHighlight {
  const factory UserHighlight({
    required String id,
    required String documentId,
    required String sectionId,
    required int startOffset,
    required int endOffset,
    required String colorCode,
    String? annotationText,
    required String createdAt,
  }) = _UserHighlight;

  factory UserHighlight.fromJson(Map<String, dynamic> json) =>
      _$UserHighlightFromJson(json);
}

@freezed
class HighlightCreate with _$HighlightCreate {
  const factory HighlightCreate({
    required String documentId,
    required String sectionId,
    required int startOffset,
    required int endOffset,
    required String colorCode,
    String? annotationText,
  }) = _HighlightCreate;

  factory HighlightCreate.fromJson(Map<String, dynamic> json) =>
      _$HighlightCreateFromJson(json);
}

// =============================================================================
// SECTIONS RESPONSE
// =============================================================================

@freezed
class SectionsWithHighlights with _$SectionsWithHighlights {
  const factory SectionsWithHighlights({
    required List<DocumentSection> sections,
    required List<UserHighlight> highlights,
    required int totalSections,
    required bool hasMore,
  }) = _SectionsWithHighlights;

  factory SectionsWithHighlights.fromJson(Map<String, dynamic> json) =>
      _$SectionsWithHighlightsFromJson(json);
}

// NOTE: SearchMatch, SearchResult, SearchResponse, PageInfo, PagesResponse
// are defined in workspace_service.dart as regular classes (non-freezed)
// to avoid code generation issues and duplication.

// =============================================================================
// CHAT CONTEXT MODELS
// =============================================================================

@freezed
class ChatContextRequest with _$ChatContextRequest {
  const factory ChatContextRequest({
    required String query,
    String? documentId,
    List<String>? filterColors,
  }) = _ChatContextRequest;

  factory ChatContextRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatContextRequestFromJson(json);
}

@freezed
class ChatContextResponse with _$ChatContextResponse {
  const factory ChatContextResponse({
    required String contextText,
    required String contextSource, // 'highlights' or 'rag'
    @Default([]) List<Map<String, dynamic>> highlightsUsed,
    @Default([]) List<String> documentsSearched,
    List<String>? colorsFiltered,
    int? totalHighlights,
    String? message,
  }) = _ChatContextResponse;

  factory ChatContextResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatContextResponseFromJson(json);
}

// =============================================================================
// HIGHLIGHT COLOR DEFINITIONS
// =============================================================================

class HighlightColor {
  final String code;
  final String name;
  final int hexValue;
  final String description;

  const HighlightColor({
    required this.code,
    required this.name,
    required this.hexValue,
    required this.description,
  });
}

const Map<String, HighlightColor> highlightColors = {
  'red': HighlightColor(
    code: 'red',
    name: 'Red',
    hexValue: 0xFFef4444,
    description: 'Important / Critical',
  ),
  'orange': HighlightColor(
    code: 'orange',
    name: 'Orange',
    hexValue: 0xFFf97316,
    description: 'Questions / Unclear',
  ),
  'yellow': HighlightColor(
    code: 'yellow',
    name: 'Yellow',
    hexValue: 0xFFeab308,
    description: 'Key Concepts',
  ),
  'green': HighlightColor(
    code: 'green',
    name: 'Green',
    hexValue: 0xFF22c55e,
    description: 'Understood / Good',
  ),
  'blue': HighlightColor(
    code: 'blue',
    name: 'Blue',
    hexValue: 0xFF3b82f6,
    description: 'Definitions',
  ),
  'purple': HighlightColor(
    code: 'purple',
    name: 'Purple',
    hexValue: 0xFFa855f7,
    description: 'Examples',
  ),
};

