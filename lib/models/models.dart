// Data models - equivalent to types.tsx
// REGENERATE: Force build_runner to regenerate this file
import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

// ============================================================================
// EXAM MODELS
// ============================================================================

@freezed
class ExamAnswer with _$ExamAnswer {
  const factory ExamAnswer({
    int? id,
    required String text,
    @JsonKey(name: 'is_correct') required bool isCorrect,
    @JsonKey(name: 'question_id') int? questionId,
  }) = _ExamAnswer;

  factory ExamAnswer.fromJson(Map<String, dynamic> json) =>
      _$ExamAnswerFromJson(json);
}

@freezed
class ExamQuestion with _$ExamQuestion {
  const factory ExamQuestion({
    int? id,
    required String text,
    @JsonKey(name: 'exam_id') int? examId,
    required List<ExamAnswer> answers,
  }) = _ExamQuestion;

  factory ExamQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionFromJson(json);
}

@freezed
class Exam with _$Exam {
  const factory Exam({
    required int id,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
    @JsonKey(name: 'user_id') int? userId,
    @JsonKey(name: 'conversation_id') int? conversationId,
    @Default([]) List<ExamQuestion> questions,
    // Sharing related fields
    @JsonKey(name: 'is_template') bool? isTemplate,
    @JsonKey(name: 'template_id') int? templateId,
    @JsonKey(name: 'is_shared') bool? isShared,
    @JsonKey(name: 'is_own') bool? isOwn,
    @JsonKey(name: 'original_exam_id') int? originalExamId,
    @JsonKey(name: 'added_at') String? addedAt,
    @JsonKey(name: 'code_used') String? codeUsed,
    @JsonKey(name: 'access_type') String? accessType,
  }) = _Exam;

  factory Exam.fromJson(Map<String, dynamic> json) => _$ExamFromJson(json);
}

@freezed
class ExamInfo with _$ExamInfo {
  const factory ExamInfo({
    required int id,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
    @JsonKey(name: 'user_id') int? userId,
    @JsonKey(name: 'conversation_id') int? conversationId,
    @JsonKey(name: 'question_count') @Default(0) int questionCount,
    // Sharing related fields
    @JsonKey(name: 'is_template') bool? isTemplate,
    @JsonKey(name: 'template_id') int? templateId,
    @JsonKey(name: 'is_shared') bool? isShared,
    @JsonKey(name: 'is_own') bool? isOwn,
    @JsonKey(name: 'original_exam_id') int? originalExamId,
    @JsonKey(name: 'added_at') String? addedAt,
    @JsonKey(name: 'code_used') String? codeUsed,
    @JsonKey(name: 'access_type') String? accessType,
  }) = _ExamInfo;

  factory ExamInfo.fromJson(Map<String, dynamic> json) =>
      _$ExamInfoFromJson(json);
}

// ============================================================================
// FLASHCARD MODELS
// ============================================================================

@freezed
class Flashcard with _$Flashcard {
  const factory Flashcard({
    int? id,
    required String question,
    required String answer,
    @JsonKey(name: 'media_url') String? mediaUrl,
    int? repetitions,
    @JsonKey(name: 'deck_id') int? deckId,
  }) = _Flashcard;

  factory Flashcard.fromJson(Map<String, dynamic> json) =>
      _$FlashcardFromJson(json);
}

@freezed
class DeckInfo with _$DeckInfo {
  const factory DeckInfo({
    @JsonKey(name: 'access_type') String? accessType,
    required int id,
    @JsonKey(name: 'user_id') int? userId,
    required String name,
    String? description,
    @JsonKey(name: 'conversation_id') int? conversationId,
    @JsonKey(name: 'flashcard_count') required int flashcardCount,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'last_session') String? lastSession,
    @JsonKey(name: 'is_template') bool? isTemplate,
    @JsonKey(name: 'template_id') int? templateId,
    @JsonKey(name: 'is_shared') bool? isShared,
    @JsonKey(name: 'is_own') bool? isOwn,
    @JsonKey(name: 'original_deck_id') int? originalDeckId,
    @JsonKey(name: 'added_at') String? addedAt,
    @JsonKey(name: 'code_used') String? codeUsed,
  }) = _DeckInfo;

  factory DeckInfo.fromJson(Map<String, dynamic> json) =>
      _$DeckInfoFromJson(json);
}

@freezed
class Deck with _$Deck {
  const factory Deck({
    required int id,
    @JsonKey(name: 'user_id') int? userId,
    required String name,
    String? description,
    @Default([]) List<Flashcard> flashcards,
    @JsonKey(name: 'conversation_id') int? conversationId,
    // Sharing related fields
    @JsonKey(name: 'is_template') bool? isTemplate,
    @JsonKey(name: 'template_id') int? templateId,
  }) = _Deck;

  factory Deck.fromJson(Map<String, dynamic> json) => _$DeckFromJson(json);
}

// ============================================================================
// SHARING MODELS
// ============================================================================

@freezed
class ShareableContent with _$ShareableContent {
  const factory ShareableContent({
    required int id,
    @JsonKey(name: 'share_code') required String shareCode,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'content_id') required int contentId,
    @JsonKey(name: 'creator_id') required int creatorId,
    @JsonKey(name: 'is_public') required bool isPublic,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'access_count') required int accessCount,
  }) = _ShareableContent;

  factory ShareableContent.fromJson(Map<String, dynamic> json) =>
      _$ShareableContentFromJson(json);
}

@freezed
class ShareCodeInfo with _$ShareCodeInfo {
  const factory ShareCodeInfo({
    @JsonKey(name: 'content_id') required int contentId,
    required String name,
    String? description,
    @JsonKey(name: 'creator_id') int? creatorId,
    @JsonKey(name: 'creator_name') String? creatorName,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'access_count') required int accessCount,
    required int itemCount,
    @JsonKey(name: 'content_type') String? contentType,
    @JsonKey(name: 'already_added') bool? alreadyAdded,
    @JsonKey(name: 'is_own_deck') bool? isOwnDeck,
    @JsonKey(name: 'is_own_exam') bool? isOwnExam,
  }) = _ShareCodeInfo;

  /// Custom fromJson to handle both deck and exam responses
  factory ShareCodeInfo.fromJson(Map<String, dynamic> json) {
    // Handle both deck and exam naming conventions
    final String name = json['deck_name'] as String? ??
                        json['exam_name'] as String? ??
                        json['name'] as String? ??
                        'Unknown';

    final String? description = json['deck_description'] as String? ??
                                json['exam_description'] as String? ??
                                json['description'] as String?;

    final int itemCount = (json['flashcard_count'] as num?)?.toInt() ??
                          (json['question_count'] as num?)?.toInt() ??
                          (json['item_count'] as num?)?.toInt() ??
                          0;

    return ShareCodeInfo(
      contentId: (json['content_id'] as num).toInt(),
      name: name,
      description: description,
      creatorId: (json['creator_id'] as num?)?.toInt(),
      creatorName: json['creator_name'] as String?,
      createdAt: json['created_at'] as String,
      accessCount: (json['access_count'] as num).toInt(),
      itemCount: itemCount,
      contentType: json['content_type'] as String?,
      alreadyAdded: json['already_added'] as bool?,
      isOwnDeck: json['is_own_deck'] as bool?,
      isOwnExam: json['is_own_exam'] as bool?,
    );
  }
}

@freezed
class MySharedCode with _$MySharedCode {
  const factory MySharedCode({
    @JsonKey(name: 'share_code') required String shareCode,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'content_id') required int contentId,
    @JsonKey(name: 'content_name') required String contentName,
    @JsonKey(name: 'item_count') required int itemCount,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'access_count') required int accessCount,
  }) = _MySharedCode;

  factory MySharedCode.fromJson(Map<String, dynamic> json) =>
      _$MySharedCodeFromJson(json);
}

// ============================================================================
// CONVERSATION MODELS
// ============================================================================

/// Represents a step in the agent's processing pipeline
@freezed
class MessageStep with _$MessageStep {
  const factory MessageStep({
    required String content,
    required String status, // "loading" or "complete"
  }) = _MessageStep;

  factory MessageStep.fromJson(Map<String, dynamic> json) =>
      _$MessageStepFromJson(json);
}

/// Represents a navigation action (created flashcards/exam)
@freezed
class MessageAction with _$MessageAction {
  const factory MessageAction({
    required String type, // "flashcards" or "exam"
    required int id,
    required String name,
    required int count,
  }) = _MessageAction;

  factory MessageAction.fromJson(Map<String, dynamic> json) =>
      _$MessageActionFromJson(json);
}

/// Metadata attached to bot messages
@freezed
class MessageMetadata with _$MessageMetadata {
  const factory MessageMetadata({
    List<MessageStep>? steps,
    List<MessageAction>? actions,
  }) = _MessageMetadata;

  factory MessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$MessageMetadataFromJson(json);
}

@freezed
class Message with _$Message {
  // Wymagane dla extension methods
  const Message._();

  const factory Message({
    required String role,
    required String content,
    String? timestamp,
    // JSON string that will be parsed to MessageMetadata
    String? metadata,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

// Extension to parse metadata
extension MessageExtension on Message {
  /// Parse the metadata JSON string into MessageMetadata object
  MessageMetadata? get parsedMetadata {
    if (metadata == null || metadata!.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(metadata!);
      if (decoded is Map<String, dynamic>) {
        return MessageMetadata.fromJson(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if this message has any actions (generated flashcards/exams)
  bool get hasActions {
    final meta = parsedMetadata;
    return meta?.actions != null && meta!.actions!.isNotEmpty;
  }

  /// Check if this message has any steps
  bool get hasSteps {
    final meta = parsedMetadata;
    return meta?.steps != null && meta!.steps!.isNotEmpty;
  }
}

@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required int id,
    required String title,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
    List<Message>? messages,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

// ============================================================================
// USER & AUTH MODELS
// ============================================================================

@freezed
class User with _$User {
  const factory User({
    required int id,
    required String email,
    String? name,
    String? role,
    @JsonKey(name: 'role_expiry') String? roleExpiry,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required bool authenticated,
    User? user,
    String? message,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

// ============================================================================
// FILE MODELS
// ============================================================================

@freezed
class UploadedFile with _$UploadedFile {
  const factory UploadedFile({
    required int id,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'file_description') required String fileDescription,
    required String category,
    @JsonKey(name: 'uploaded_at') required String uploadedAt,
    @JsonKey(name: 'start_page') int? startPage,
    @JsonKey(name: 'end_page') int? endPage,
  }) = _UploadedFile;

  factory UploadedFile.fromJson(Map<String, dynamic> json) =>
      _$UploadedFileFromJson(json);
}

// ============================================================================
// API RESPONSE MODELS
// ============================================================================

@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success({required T data}) = Success<T>;
  const factory ApiResponse.error({required String message}) = Error<T>;
}

