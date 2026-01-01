import '../models/models.dart';
import 'api_service.dart';

/// Service for exam-related API operations
class ExamService {
  final ApiService _api = ApiService();

  // ============================================================================
  // EXAM CRUD OPERATIONS
  // ============================================================================

  /// Fetch all exams for the current user
  Future<List<ExamInfo>> fetchExamInfos({bool includeShared = true}) async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/exams/',
        queryParameters: {'include_shared': includeShared},
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!.map((json) {
          final map = json as Map<String, dynamic>;
          return ExamInfo(
            id: map['id'] as int,
            name: map['name'] as String,
            description: map['description'] as String? ?? '',
            createdAt: map['created_at'] as String? ?? '',
            userId: map['user_id'] as int? ?? 0,
            conversationId: map['conversation_id'] as int?,
            questionCount: map['question_count'] as int? ?? 0,
            isTemplate: map['is_template'] as bool?,
            templateId: map['template_id'] as int?,
            isShared: map['is_shared'] as bool?,
            isOwn: map['is_own'] as bool?,
            originalExamId: map['original_exam_id'] as int?,
            addedAt: map['added_at'] as String?,
            codeUsed: map['code_used'] as String?,
            accessType: map['access_type'] as String?,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch a single exam with all questions and answers
  Future<Exam?> fetchExam(int examId) async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/exams/$examId/',
      );

      if (response.statusCode == 200 && response.data != null) {
        return Exam.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new exam
  Future<Exam?> createExam({
    required String name,
    required String description,
    required List<ExamQuestion> questions,
    int? conversationId,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/exams/',
        data: {
          'name': name,
          'description': description,
          'questions': questions.map((q) {
            return {
              'text': q.text,
              'answers': q.answers.map((a) {
                return {
                  'text': a.text,
                  'is_correct': a.isCorrect,
                };
              }).toList(),
            };
          }).toList(),
          'conversation_id': conversationId ?? 0,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Exam.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing exam
  Future<bool> updateExam({
    required int examId,
    required String name,
    required String description,
    required List<ExamQuestion> questions,
    int? conversationId,
  }) async {
    try {
      final response = await _api.ragPut<Map<String, dynamic>>(
        '/exams/$examId/',
        data: {
          'name': name,
          'description': description,
          'questions': questions.map((q) {
            return {
              'id': q.id,
              'text': q.text,
              'answers': q.answers.map((a) {
                final answerMap = <String, dynamic>{
                  'text': a.text,
                  'is_correct': a.isCorrect,
                };
                if (a.id != null) {
                  answerMap['id'] = a.id;
                }
                return answerMap;
              }).toList(),
            };
          }).toList(),
          'conversation_id': conversationId ?? 0,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an exam
  Future<bool> deleteExam(int examId) async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/exams/$examId/',
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // EXAM RESULTS
  // ============================================================================

  /// Submit exam results
  Future<Map<String, dynamic>?> submitExamResult({
    required int examId,
    required List<ExamResultAnswer> answers,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/exams/submit/',
        data: {
          'exam_id': examId,
          'answers': answers.map((a) {
            return {
              'question_id': a.questionId,
              'selected_answer_id': a.selectedAnswerId,
              'answer_time': a.answerTime,
            };
          }).toList(),
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // SHARING OPERATIONS
  // ============================================================================

  /// Share an exam and get share code
  Future<String?> shareExam(int examId) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/exams/$examId/share',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!['share_code'] as String?;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get share code info
  Future<ShareCodeInfo?> getShareCodeInfo(String code) async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/exams/share-info/$code',
      );

      if (response.statusCode == 200 && response.data != null) {
        return ShareCodeInfo.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Add exam by share code
  Future<bool> addExamByCode(String code) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/exams/add-by-code',
        data: {'code': code.toUpperCase()},
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Remove shared exam from library
  Future<bool> removeSharedExam(int examId) async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/exams/shared/$examId',
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's shared codes for exams
  Future<List<MySharedCode>> getMySharedCodes() async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/exams/my-shared-codes',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) {
              final map = json as Map<String, dynamic>;
              // Normalize exam-specific fields to generic format
              return MySharedCode.fromJson({
                'share_code': map['share_code'],
                'content_type': 'exam',
                'content_id': map['content_id'],
                'content_name': map['exam_name'] ?? map['content_name'] ?? 'Unknown',
                'item_count': map['question_count'] ?? map['item_count'] ?? 0,
                'created_at': map['created_at'] ?? '',
                'access_count': map['access_count'] ?? 0,
              });
            })
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate a share code
  Future<bool> deactivateShareCode(String code) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/exams/shared-code/$code/deactivate',
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}

/// Model for exam result answer submission
class ExamResultAnswer {
  final int questionId;
  final int selectedAnswerId;
  final String answerTime;

  ExamResultAnswer({
    required this.questionId,
    required this.selectedAnswerId,
    required this.answerTime,
  });
}
