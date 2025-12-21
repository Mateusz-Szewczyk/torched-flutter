// Data models - equivalent to types.tsx
// REGENERATE: Force build_runner to regenerate this file
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
    required String description,
    @JsonKey(name: 'creator_name') required String creatorName,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'access_count') required int accessCount,
    @JsonKey(name: 'item_count') required int itemCount,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'already_added') bool? alreadyAdded,
    @JsonKey(name: 'is_own_deck') bool? isOwnDeck,
    @JsonKey(name: 'is_own_exam') bool? isOwnExam,
  }) = _ShareCodeInfo;

  factory ShareCodeInfo.fromJson(Map<String, dynamic> json) =>
      _$ShareCodeInfoFromJson(json);
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

@freezed
class Message with _$Message {
  const factory Message({
    required String role,
    required String content,
    String? timestamp,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
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

