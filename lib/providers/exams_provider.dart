import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/exam_service.dart';

/// Sort options for exams
enum ExamSortOption { name, questions, recent }

/// Sort direction enum (missing before)
enum SortDirection { asc, desc }

/// Provider for managing exam state
class ExamsProvider extends ChangeNotifier {
  final ExamService _examService = ExamService();

  // ============================================================================
  // STATE
  // ============================================================================

  List<ExamInfo> _examInfos = [];
  List<ExamInfo> get examInfos => _examInfos;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Search and sort
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  ExamSortOption _sortBy = ExamSortOption.recent;
  ExamSortOption get sortBy => _sortBy;

  SortDirection _sortDirection = SortDirection.desc;
  SortDirection get sortDirection => _sortDirection;

  // Study mode
  Exam? _studyingExam;
  Exam? get studyingExam => _studyingExam;

  bool get isStudying => _studyingExam != null;

  // Sharing
  ShareCodeInfo? _shareCodeInfo;
  ShareCodeInfo? get shareCodeInfo => _shareCodeInfo;

  bool _isShareCodeLoading = false;
  bool get isShareCodeLoading => _isShareCodeLoading;

  List<MySharedCode> _mySharedCodes = [];
  List<MySharedCode> get mySharedCodes => _mySharedCodes;

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  List<ExamInfo> get filteredExamInfos {
    var result = List<ExamInfo>.from(_examInfos);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((exam) {
        final desc = exam.description; // ensure non-null
        return exam.name.toLowerCase().contains(query) ||
            (desc.isNotEmpty && desc.toLowerCase().contains(query));
      }).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case ExamSortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case ExamSortOption.questions:
          comparison = a.questionCount.compareTo(b.questionCount);
          break;
        case ExamSortOption.recent:
          comparison = a.id.compareTo(b.id);
          break;
      }
      return _sortDirection == SortDirection.asc ? comparison : -comparison;
    });

    return result;
  }

  // ============================================================================
  // EXAM CRUD OPERATIONS
  // ============================================================================

  /// Fetch all exam infos
  Future<void> fetchExamInfos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _examInfos = await _examService.fetchExamInfos(includeShared: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new exam
  Future<bool> createExam({
    required String name,
    required String description,
    required List<ExamQuestion> questions,
  }) async {
    try {
      final exam = await _examService.createExam(
        name: name,
        description: description,
        questions: questions,
      );

      if (exam != null) {
        await fetchExamInfos();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an exam
  Future<bool> updateExam({
    required int examId,
    required String name,
    required String description,
    required List<ExamQuestion> questions,
  }) async {
    try {
      final success = await _examService.updateExam(
        examId: examId,
        name: name,
        description: description,
        questions: questions,
      );

      if (success) {
        await fetchExamInfos();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete an exam
  Future<bool> deleteExam(int examId) async {
    try {
      final success = await _examService.deleteExam(examId);

      if (success) {
        _examInfos.removeWhere((e) => e.id == examId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // STUDY MODE
  // ============================================================================

  /// Start studying an exam
  Future<bool> startStudy(ExamInfo examInfo) async {
    try {
      // Fetch full exam with questions
      final exam = await _examService.fetchExam(examInfo.id);

      if (exam == null) {
        _error = 'Failed to load exam';
        notifyListeners();
        return false;
      }

      if (exam.questions.isEmpty) {
        _error = 'Exam has no questions';
        notifyListeners();
        return false;
      }

      _studyingExam = exam;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Exit study mode
  void exitStudy() {
    _studyingExam = null;
    notifyListeners();
  }

  /// Submit exam results
  Future<bool> submitExamResult(List<ExamResultAnswer> answers) async {
    if (_studyingExam == null) return false;

    try {
      final result = await _examService.submitExamResult(
        examId: _studyingExam!.id,
        answers: answers,
      );

      return result != null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // SHARING OPERATIONS
  // ============================================================================

  /// Share an exam
  Future<String?> shareExam(int examId) async {
    try {
      return await _examService.shareExam(examId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Get share code info
  Future<void> getShareCodeInfo(String code) async {
    if (code.length != 12) {
      _shareCodeInfo = null;
      notifyListeners();
      return;
    }

    _isShareCodeLoading = true;
    notifyListeners();

    try {
      _shareCodeInfo = await _examService.getShareCodeInfo(code);
    } catch (e) {
      _shareCodeInfo = null;
      // Don't set error string here, let the UI handle the null info state
      // This prevents flash of error message while typing
    } finally {
      _isShareCodeLoading = false;
      notifyListeners();
    }
  }

  /// Clear share code info
  void clearShareCodeInfo() {
    _shareCodeInfo = null;
    notifyListeners();
  }

  /// Add exam by code
  Future<bool> addExamByCode(String code) async {
    try {
      // Service call returns Map<String, dynamic>, but we just need success/fail via exception
      await _examService.addExamByCode(code);

      // If we reach here, it was successful
      await fetchExamInfos();
      clearShareCodeInfo();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove shared exam
  Future<bool> removeSharedExam(int examId) async {
    try {
      final success = await _examService.removeSharedExam(examId);

      if (success) {
        await fetchExamInfos();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Fetch my shared codes
  Future<void> fetchMySharedCodes() async {
    try {
      _mySharedCodes = await _examService.getMySharedCodes();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Deactivate share code
  Future<bool> deactivateShareCode(String code) async {
    try {
      final success = await _examService.deactivateShareCode(code);

      if (success) {
        _mySharedCodes.removeWhere((c) => c.shareCode == code);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // SEARCH AND SORT
  // ============================================================================

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(ExamSortOption option) {
    _sortBy = option;
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortDirection = _sortDirection == SortDirection.asc
        ? SortDirection.desc
        : SortDirection.asc;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}