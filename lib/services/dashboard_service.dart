import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Dashboard Service - fetches user statistics and study data
/// Equivalent to dashboard API calls in React app

class DashboardService {
  final ApiService _api = ApiService();

  /// Fetch all dashboard data for the logged-in user
  Future<DashboardData?> fetchDashboardData() async {
    try {
      debugPrint('[DashboardService] Fetching dashboard data...');
      final response = await _api.ragGet('/dashboard/');
      debugPrint('[DashboardService] Response status: ${response.statusCode}');
      debugPrint('[DashboardService] Response data type: ${response.data?.runtimeType}');

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('[DashboardService] Parsing dashboard data...');
        try {
          final data = DashboardData.fromJson(response.data as Map<String, dynamic>);
          debugPrint('[DashboardService] Dashboard data parsed successfully');
          debugPrint('[DashboardService] Study records count: ${data.studyRecords.length}');
          debugPrint('[DashboardService] Exam results count: ${data.examResults.length}');
          return data;
        } catch (parseError, parseStack) {
          debugPrint('[DashboardService] PARSE ERROR: $parseError');
          debugPrint('[DashboardService] Parse stack: $parseStack');
          // Return a minimal valid object to avoid null crash
          return DashboardData(
            studyRecords: [],
            userFlashcards: [],
            studySessions: [],
            examResults: [],
            sessionDurations: [],
            examDailyAverage: [],
            flashcardDailyAverage: [],
            deckNames: {},
          );
        }
      }
      debugPrint('[DashboardService] No data returned from API');
      // Return minimal object instead of null
      return DashboardData(
        studyRecords: [],
        userFlashcards: [],
        studySessions: [],
        examResults: [],
        sessionDurations: [],
        examDailyAverage: [],
        flashcardDailyAverage: [],
        deckNames: {},
      );
    } catch (e, stackTrace) {
      debugPrint('[DashboardService] Error fetching dashboard data: $e');
      debugPrint('[DashboardService] Stack trace: $stackTrace');
      // Rethrow to let widget handle error state properly
      rethrow;
    }
  }

  /// Fetch learning calendar data (GitHub-style contribution graph)
  Future<CalendarData?> fetchCalendarData({
    int monthsBack = 3,
    int monthsForward = 1,
  }) async {
    try {
      final response = await _api.ragGet(
        '/dashboard/calendar',
        queryParameters: {
          'months_back': monthsBack,
          'months_forward': monthsForward,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return CalendarData.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching calendar data: $e');
      return null;
    }
  }
}

// =============================================
// CALENDAR DATA MODELS
// =============================================

/// Calendar data model for GitHub-style contribution graph
class CalendarData {
  final Map<String, CalendarDay> history;
  final Map<String, CalendarDay> scheduled;
  final Map<String, CalendarDay> overdue; // Added overdue map
  final CalendarStats stats;
  final CalendarRange range;
  final String? generatedAt;

  CalendarData({
    required this.history,
    required this.scheduled,
    required this.overdue, // Added overdue map
    required this.stats,
    required this.range,
    this.generatedAt,
  });

  factory CalendarData.fromJson(Map<String, dynamic> json) {
    return CalendarData(
      history: (json['history'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CalendarDay.fromJson(value as Map<String, dynamic>)),
      ) ?? {},
      scheduled: (json['scheduled'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CalendarDay.fromJson(value as Map<String, dynamic>)),
      ) ?? {},
      overdue: (json['overdue'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CalendarDay.fromJson(value as Map<String, dynamic>)),
      ) ?? {}, // Added overdue parsing
      stats: CalendarStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      range: CalendarRange.fromJson(json['range'] as Map<String, dynamic>? ?? {}),
      generatedAt: json['generated_at'] as String?,
    );
  }
}

/// Single day data in calendar
class CalendarDay {
  final int count;
  final List<DeckCount> decks;

  CalendarDay({
    required this.count,
    required this.decks,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      count: json['count'] as int? ?? 0,
      decks: (json['decks'] as List<dynamic>?)
          ?.map((e) => DeckCount.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Deck count for a day
class DeckCount {
  final String name;
  final int count;

  DeckCount({required this.name, required this.count});

  factory DeckCount.fromJson(Map<String, dynamic> json) {
    return DeckCount(
      name: json['name'] as String? ?? 'Unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Calendar statistics
class CalendarStats {
  final int maxCount;
  final int totalDaysStudied;
  final int currentStreak;
  final int longestStreak;
  final bool isActiveToday;
  final int cardsDueToday;
  final int totalFlashcardsYear;
  final bool hasStudiedToday;
  final List<DeckCount> decksDueToday;

  CalendarStats({
    required this.maxCount,
    required this.totalDaysStudied,
    required this.currentStreak,
    required this.longestStreak,
    required this.isActiveToday,
    required this.cardsDueToday,
    this.totalFlashcardsYear = 0,
    this.hasStudiedToday = false,
    this.decksDueToday = const [],
  });

  factory CalendarStats.fromJson(Map<String, dynamic> json) {
    return CalendarStats(
      maxCount: json['max_count'] as int? ?? 0,
      totalDaysStudied: json['total_days_studied'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      isActiveToday: json['is_active_today'] as bool? ?? false,
      cardsDueToday: json['cards_due_today'] as int? ?? 0,
      totalFlashcardsYear: json['total_flashcards_year'] as int? ?? 0,
      hasStudiedToday: json['has_studied_today'] as bool? ?? false,
      decksDueToday: (json['decks_due_today'] as List<dynamic>?)
          ?.map((e) => DeckCount.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Calendar date range
class CalendarRange {
  final String start;
  final String end;

  CalendarRange({required this.start, required this.end});

  factory CalendarRange.fromJson(Map<String, dynamic> json) {
    return CalendarRange(
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }
}

// =============================================
// EXISTING MODELS
// =============================================

/// Dashboard data model
class DashboardData {
  final List<StudyRecord> studyRecords;
  final List<UserFlashcard> userFlashcards;
  final List<StudySession> studySessions;
  final List<ExamResult> examResults;
  final List<SessionDuration> sessionDurations;
  final List<DailyAverage> examDailyAverage;
  final List<DailyAverage> flashcardDailyAverage;
  final Map<int, String> deckNames;

  // New extended fields
  final TimePeriodStats? timePeriodStats;
  final Comparisons? comparisons;
  final StudyStreak? studyStreak;
  final FlashcardMastery? flashcardMastery;
  final QuickStats? quickStats;
  final MaterialCounts? materialCounts;
  final String? generatedAt;

  DashboardData({
    required this.studyRecords,
    required this.userFlashcards,
    required this.studySessions,
    required this.examResults,
    required this.sessionDurations,
    required this.examDailyAverage,
    required this.flashcardDailyAverage,
    required this.deckNames,
    this.timePeriodStats,
    this.comparisons,
    this.studyStreak,
    this.flashcardMastery,
    this.quickStats,
    this.materialCounts,
    this.generatedAt,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      studyRecords: (json['study_records'] as List<dynamic>?)
          ?.map((e) => StudyRecord.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      userFlashcards: (json['user_flashcards'] as List<dynamic>?)
          ?.map((e) => UserFlashcard.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      studySessions: (json['study_sessions'] as List<dynamic>?)
          ?.map((e) => StudySession.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      examResults: (json['exam_results'] as List<dynamic>?)
          ?.map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      sessionDurations: (json['session_durations'] as List<dynamic>?)
          ?.map((e) => SessionDuration.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      examDailyAverage: (json['exam_daily_average'] as List<dynamic>?)
          ?.map((e) => DailyAverage.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      flashcardDailyAverage: (json['flashcard_daily_average'] as List<dynamic>?)
          ?.map((e) => DailyAverage.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      deckNames: (json['deck_names'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(int.tryParse(key) ?? 0, value.toString()),
      ) ?? {},
      // New fields
      timePeriodStats: json['time_period_stats'] != null
          ? TimePeriodStats.fromJson(json['time_period_stats'] as Map<String, dynamic>)
          : null,
      comparisons: json['comparisons'] != null
          ? Comparisons.fromJson(json['comparisons'] as Map<String, dynamic>)
          : null,
      studyStreak: json['study_streak'] != null
          ? StudyStreak.fromJson(json['study_streak'] as Map<String, dynamic>)
          : null,
      flashcardMastery: json['flashcard_mastery'] != null
          ? FlashcardMastery.fromJson(json['flashcard_mastery'] as Map<String, dynamic>)
          : null,
      quickStats: json['quick_stats'] != null
          ? QuickStats.fromJson(json['quick_stats'] as Map<String, dynamic>)
          : null,
      materialCounts: json['material_counts'] != null
          ? MaterialCounts.fromJson(json['material_counts'] as Map<String, dynamic>)
          : null,
      generatedAt: json['generated_at'] as String?,
    );
  }

  /// Calculate summary statistics - uses new backend data when available
  DashboardSummary getSummary() {
    // If new backend data is available, use it directly
    if (quickStats != null && studyStreak != null) {
      return DashboardSummary(
        totalStudyTime: quickStats!.studyHoursThisMonth,
        averageExamScore: timePeriodStats?.thisMonth.averageExamScore ?? 0,
        totalFlashcards: quickStats!.flashcardsThisMonth,
        studyStreak: studyStreak!.current,
      );
    }

    // Fallback to calculating from raw data (backward compatibility)
    final totalStudyTime = sessionDurations.fold<double>(
      0, (sum, session) => sum + session.durationHours,
    );

    final validExams = examResults.where((e) => e.score >= 0 && e.score <= 100);
    final averageExamScore = validExams.isEmpty
        ? 0.0
        : validExams.fold<double>(0, (sum, e) => sum + e.score) / validExams.length;

    final totalFlashcards = studyRecords.length;
    final calculatedStreak = _calculateStudyStreak();

    return DashboardSummary(
      totalStudyTime: totalStudyTime,
      averageExamScore: averageExamScore,
      totalFlashcards: totalFlashcards,
      studyStreak: calculatedStreak,
    );
  }

  /// Get extended summary with comparisons
  ExtendedDashboardSummary getExtendedSummary() {
    final basic = getSummary();

    // Calculate last week's flashcards from comparison or study records
    int flashcardsLastWeek = 0;
    if (comparisons?.weekOverWeek != null) {
      final current = quickStats?.flashcardsThisWeek ?? 0;
      final changePercent = comparisons!.weekOverWeek.flashcards.percentage;
      // Safe calculation to avoid NaN and division by zero
      final divisor = 1 + changePercent / 100;
      if (changePercent == 0) {
        flashcardsLastWeek = current;
      } else if (divisor.isFinite && divisor != 0 && changePercent != 100) {
        // Calculate previous value: current = previous * (1 + change/100)
        // previous = current / (1 + change/100)
        final result = current / divisor;
        flashcardsLastWeek = result.isFinite ? result.round() : 0;
      } else if (changePercent == 0) {
        flashcardsLastWeek = current;
      }
    } else {
      // Calculate from study records
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      flashcardsLastWeek = studyRecords.where((r) {
        try {
          final date = DateTime.parse(r.reviewedAt);
          return date.isAfter(twoWeeksAgo) && date.isBefore(oneWeekAgo);
        } catch (_) {
          return false;
        }
      }).length;
    }

    // Calculate last month's flashcards
    int flashcardsLastMonth = 0;
    if (comparisons?.monthOverMonth != null) {
      final current = quickStats?.flashcardsThisMonth ?? 0;
      final changePercent = comparisons!.monthOverMonth.flashcards.percentage;
      // Safe calculation to avoid NaN and division by zero
      final divisor = 1 + changePercent / 100;
      if (changePercent == 0) {
        flashcardsLastMonth = current;
      } else if (divisor.isFinite && divisor != 0 && changePercent != -100) {
        final result = current / divisor;
        flashcardsLastMonth = result.isFinite ? result.round() : 0;
      }
    } else {
      // Calculate from study records
      final now = DateTime.now();
      final twoMonthsAgo = DateTime(now.year, now.month - 2, now.day);
      final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
      flashcardsLastMonth = studyRecords.where((r) {
        try {
          final date = DateTime.parse(r.reviewedAt);
          return date.isAfter(twoMonthsAgo) && date.isBefore(oneMonthAgo);
        } catch (_) {
          return false;
        }
      }).length;
    }

    return ExtendedDashboardSummary(
      // Basic stats
      totalStudyTime: basic.totalStudyTime,
      averageExamScore: basic.averageExamScore,
      totalFlashcards: basic.totalFlashcards,
      studyStreak: basic.studyStreak,

      // Extended from backend
      streakLongest: studyStreak?.longest ?? 0,
      isActiveToday: studyStreak?.isActiveToday ?? false,

      // Today stats
      flashcardsToday: quickStats?.flashcardsToday ?? 0,
      studyHoursToday: quickStats?.studyHoursToday ?? 0,
      examsToday: quickStats?.examsToday ?? 0,

      // Week stats
      flashcardsThisWeek: quickStats?.flashcardsThisWeek ?? 0,
      flashcardsLastWeek: flashcardsLastWeek,
      studyHoursThisWeek: quickStats?.studyHoursThisWeek ?? 0,
      examsThisWeek: quickStats?.examsThisWeek ?? 0,

      // Month stats
      flashcardsThisMonth: quickStats?.flashcardsThisMonth ?? 0,
      flashcardsLastMonth: flashcardsLastMonth,
      studyHoursThisMonth: quickStats?.studyHoursThisMonth ?? 0,
      examsThisMonth: quickStats?.examsThisMonth ?? 0,

      // Year stats
      flashcardsThisYear: quickStats?.flashcardsThisYear ?? 0,

      // Cards due
      cardsDueToday: flashcardMastery?.cardsDueToday ?? quickStats?.cardsDueToday ?? 0,

      // Mastery
      masteredCards: flashcardMastery?.mastered ?? 0,
      learningCards: flashcardMastery?.learning ?? 0,
      difficultCards: flashcardMastery?.difficult ?? 0,
      masteryPercentage: flashcardMastery?.masteryPercentage ?? 0,

      // Comparisons
      weekComparison: comparisons?.weekOverWeek,
      monthComparison: comparisons?.monthOverMonth,
    );
  }

  int _calculateStudyStreak() {
    if (studySessions.isEmpty) return 0;

    // Get unique study dates
    final studyDates = studySessions
        .map((s) => s.startedAt.split('T')[0])
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending

    if (studyDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayString = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // Check if last study was today or yesterday
    final lastStudyDate = studyDates.first;
    if (lastStudyDate != todayString && lastStudyDate != yesterdayString) {
      return 0;
    }

    int streak = 0;
    DateTime currentDate = DateTime.parse(lastStudyDate);

    for (final studyDate in studyDates) {
      final currentDateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      if (studyDate == currentDateString) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Get flashcard rating distribution
  List<RatingDistribution> getFlashcardRatingDistribution() {
    final ratingMap = <int, int>{};
    for (final record in studyRecords) {
      ratingMap[record.rating] = (ratingMap[record.rating] ?? 0) + 1;
    }

    final ratingLabels = {
      0: 'Hard',
      3: 'Good',
      5: 'Easy',
    };

    final total = studyRecords.length;
    return ratingMap.entries
        .map((e) => RatingDistribution(
              rating: ratingLabels[e.key] ?? 'Rating ${e.key}',
              count: e.value,
              percentage: total > 0 ? (e.value / total * 100).round() : 0,
            ))
        .toList()
      ..sort((a, b) {
        final order = {'Hard': 0, 'Good': 1, 'Easy': 2};
        return (order[a.rating] ?? 3).compareTo(order[b.rating] ?? 3);
      });
  }

  /// Get exam score distribution (histogram)
  List<ScoreDistribution> getExamScoreDistribution() {
    final buckets = List.generate(11, (i) => ScoreDistribution(
      range: i < 10 ? '${i * 10}-${i * 10 + 9}' : '100',
      count: 0,
      percentage: 0,
    ));

    for (final exam in examResults) {
      if (exam.score >= 0 && exam.score <= 100) {
        final bucketIndex = exam.score == 100 ? 10 : (exam.score ~/ 10);
        buckets[bucketIndex] = ScoreDistribution(
          range: buckets[bucketIndex].range,
          count: buckets[bucketIndex].count + 1,
          percentage: 0,
        );
      }
    }

    final total = examResults.length;
    for (var i = 0; i < buckets.length; i++) {
      buckets[i] = ScoreDistribution(
        range: buckets[i].range,
        count: buckets[i].count,
        percentage: total > 0 ? (buckets[i].count / total * 100).round() : 0,
      );
    }

    return buckets;
  }

  /// Get flashcards studied by hour
  List<HourlyActivity> getFlashcardsByHour() {
    final hourMap = <int, int>{};
    for (final record in studyRecords) {
      try {
        final hour = DateTime.parse(record.reviewedAt).hour;
        hourMap[hour] = (hourMap[hour] ?? 0) + 1;
      } catch (_) {}
    }

    return hourMap.entries
        .map((e) => HourlyActivity(
              hour: '${e.key.toString().padLeft(2, '0')}:00',
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }
}

/// Dashboard summary statistics
class DashboardSummary {
  final double totalStudyTime;
  final double averageExamScore;
  final int totalFlashcards;
  final int studyStreak;

  DashboardSummary({
    required this.totalStudyTime,
    required this.averageExamScore,
    required this.totalFlashcards,
    required this.studyStreak,
  });
}

/// Extended dashboard summary with all new data
class ExtendedDashboardSummary extends DashboardSummary {
  // Extended streak info
  final int streakLongest;
  final bool isActiveToday;

  // Today stats
  final int flashcardsToday;
  final double studyHoursToday;
  final int examsToday;

  // Week stats
  final int flashcardsThisWeek;
  final int flashcardsLastWeek;
  final double studyHoursThisWeek;
  final int examsThisWeek;

  // Month stats
  final int flashcardsThisMonth;
  final int flashcardsLastMonth;
  final double studyHoursThisMonth;
  final int examsThisMonth;

  // Year stats
  final int flashcardsThisYear;

  // Cards due
  final int cardsDueToday;

  // Mastery stats
  final int masteredCards;
  final int learningCards;
  final int difficultCards;
  final double masteryPercentage;

  // Comparisons
  final ComparisonSet? weekComparison;
  final ComparisonSet? monthComparison;

  ExtendedDashboardSummary({
    required super.totalStudyTime,
    required super.averageExamScore,
    required super.totalFlashcards,
    required super.studyStreak,
    this.streakLongest = 0,
    this.isActiveToday = false,
    this.flashcardsToday = 0,
    this.studyHoursToday = 0,
    this.examsToday = 0,
    this.flashcardsThisWeek = 0,
    this.flashcardsLastWeek = 0,
    this.studyHoursThisWeek = 0,
    this.examsThisWeek = 0,
    this.flashcardsThisMonth = 0,
    this.flashcardsLastMonth = 0,
    this.studyHoursThisMonth = 0,
    this.examsThisMonth = 0,
    this.flashcardsThisYear = 0,
    this.cardsDueToday = 0,
    this.masteredCards = 0,
    this.learningCards = 0,
    this.difficultCards = 0,
    this.masteryPercentage = 0,
    this.weekComparison,
    this.monthComparison,
  });
}

/// Study record model
class StudyRecord {
  final int id;
  final int? sessionId;
  final int? userFlashcardId;
  final int rating;
  final String reviewedAt;

  StudyRecord({
    required this.id,
    this.sessionId,
    this.userFlashcardId,
    required this.rating,
    required this.reviewedAt,
  });

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      id: json['id'] as int? ?? 0,
      sessionId: json['session_id'] as int?,
      userFlashcardId: json['user_flashcard_id'] as int?,
      rating: json['rating'] as int? ?? 0,
      reviewedAt: json['reviewed_at'] as String? ?? '',
    );
  }
}

/// User flashcard model
class UserFlashcard {
  final int id;
  final int userId;
  final int flashcardId;
  final double ef;
  final int interval;
  final int repetitions;
  final String nextReview;

  UserFlashcard({
    required this.id,
    required this.userId,
    required this.flashcardId,
    required this.ef,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
  });

  factory UserFlashcard.fromJson(Map<String, dynamic> json) {
    return UserFlashcard(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      flashcardId: json['flashcard_id'] as int? ?? 0,
      ef: (json['ef'] as num?)?.toDouble() ?? 2.5,
      interval: json['interval'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReview: json['next_review'] as String? ?? '',
    );
  }
}

/// Study session model
class StudySession {
  final int id;
  final int userId;
  final int deckId;
  final String startedAt;
  final String? completedAt;

  StudySession({
    required this.id,
    required this.userId,
    required this.deckId,
    required this.startedAt,
    this.completedAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      deckId: json['deck_id'] as int? ?? 0,
      startedAt: json['started_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
    );
  }
}

/// Exam result model
class ExamResult {
  final int id;
  final int examId;
  final String examName;
  final int userId;
  final String startedAt;
  final String? completedAt;
  final double score;

  ExamResult({
    required this.id,
    required this.examId,
    required this.examName,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    required this.score,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'] as int? ?? 0,
      examId: json['exam_id'] as int? ?? 0,
      examName: json['exam_name'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      startedAt: json['started_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Session duration model
class SessionDuration {
  final String date;
  final double durationHours;

  SessionDuration({
    required this.date,
    required this.durationHours,
  });

  factory SessionDuration.fromJson(Map<String, dynamic> json) {
    return SessionDuration(
      date: json['date'] as String? ?? '',
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Daily average model (for exam scores and flashcard ratings)
class DailyAverage {
  final String date;
  final double averageScore;
  final double? averageRating;

  DailyAverage({
    required this.date,
    this.averageScore = 0,
    this.averageRating,
  });

  factory DailyAverage.fromJson(Map<String, dynamic> json) {
    return DailyAverage(
      date: json['date'] as String? ?? '',
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
    );
  }
}

/// Rating distribution model
class RatingDistribution {
  final String rating;
  final int count;
  final int percentage;

  RatingDistribution({
    required this.rating,
    required this.count,
    required this.percentage,
  });
}

/// Score distribution model (histogram)
class ScoreDistribution {
  final String range;
  final int count;
  final int percentage;

  ScoreDistribution({
    required this.range,
    required this.count,
    required this.percentage,
  });
}

/// Hourly activity model
class HourlyActivity {
  final String hour;
  final int count;

  HourlyActivity({
    required this.hour,
    required this.count,
  });
}


// =============================================
// NEW EXTENDED MODELS
// =============================================

/// Time period statistics
class TimePeriodStats {
  final PeriodStats today;
  final PeriodStats thisWeek;
  final PeriodStats lastWeek;
  final PeriodStats thisMonth;
  final PeriodStats lastMonth;
  final PeriodStats thisYear;

  TimePeriodStats({
    required this.today,
    required this.thisWeek,
    required this.lastWeek,
    required this.thisMonth,
    required this.lastMonth,
    required this.thisYear,
  });

  factory TimePeriodStats.fromJson(Map<String, dynamic> json) {
    return TimePeriodStats(
      today: PeriodStats.fromJson(json['today'] as Map<String, dynamic>? ?? {}),
      thisWeek: PeriodStats.fromJson(json['this_week'] as Map<String, dynamic>? ?? {}),
      lastWeek: PeriodStats.fromJson(json['last_week'] as Map<String, dynamic>? ?? {}),
      thisMonth: PeriodStats.fromJson(json['this_month'] as Map<String, dynamic>? ?? {}),
      lastMonth: PeriodStats.fromJson(json['last_month'] as Map<String, dynamic>? ?? {}),
      thisYear: PeriodStats.fromJson(json['this_year'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Statistics for a single time period
class PeriodStats {
  final int flashcardsStudied;
  final int studySessions;
  final int examsCompleted;
  final double averageFlashcardRating;
  final double averageExamScore;
  final double totalStudyHours;
  final int activeDays;

  PeriodStats({
    this.flashcardsStudied = 0,
    this.studySessions = 0,
    this.examsCompleted = 0,
    this.averageFlashcardRating = 0,
    this.averageExamScore = 0,
    this.totalStudyHours = 0,
    this.activeDays = 0,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      flashcardsStudied: json['flashcards_studied'] as int? ?? 0,
      studySessions: json['study_sessions'] as int? ?? 0,
      examsCompleted: json['exams_completed'] as int? ?? 0,
      averageFlashcardRating: (json['average_flashcard_rating'] as num?)?.toDouble() ?? 0,
      averageExamScore: (json['average_exam_score'] as num?)?.toDouble() ?? 0,
      totalStudyHours: (json['total_study_hours'] as num?)?.toDouble() ?? 0,
      activeDays: json['active_days'] as int? ?? 0,
    );
  }
}

/// Comparisons between time periods
class Comparisons {
  final ComparisonSet weekOverWeek;
  final ComparisonSet monthOverMonth;

  Comparisons({
    required this.weekOverWeek,
    required this.monthOverMonth,
  });

  factory Comparisons.fromJson(Map<String, dynamic> json) {
    return Comparisons(
      weekOverWeek: ComparisonSet.fromJson(json['week_over_week'] as Map<String, dynamic>? ?? {}),
      monthOverMonth: ComparisonSet.fromJson(json['month_over_month'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Set of comparison changes
class ComparisonSet {
  final ComparisonChange flashcards;
  final ComparisonChange studyHours;
  final ComparisonChange exams;
  final ComparisonChange avgRating;
  final ComparisonChange avgExamScore;

  ComparisonSet({
    required this.flashcards,
    required this.studyHours,
    required this.exams,
    required this.avgRating,
    required this.avgExamScore,
  });

  factory ComparisonSet.fromJson(Map<String, dynamic> json) {
    return ComparisonSet(
      flashcards: ComparisonChange.fromJson(json['flashcards'] as Map<String, dynamic>? ?? {}),
      studyHours: ComparisonChange.fromJson(json['study_hours'] as Map<String, dynamic>? ?? {}),
      exams: ComparisonChange.fromJson(json['exams'] as Map<String, dynamic>? ?? {}),
      avgRating: ComparisonChange.fromJson(json['avg_rating'] as Map<String, dynamic>? ?? {}),
      avgExamScore: ComparisonChange.fromJson(json['avg_exam_score'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Single comparison change value
class ComparisonChange {
  final double value;
  final double percentage;
  final String trend; // 'up', 'down', 'neutral'

  ComparisonChange({
    this.value = 0,
    this.percentage = 0,
    this.trend = 'neutral',
  });

  factory ComparisonChange.fromJson(Map<String, dynamic> json) {
    // Safe parsing with NaN/Infinity checks
    double parseDouble(dynamic val) {
      if (val == null) return 0;
      final d = (val as num?)?.toDouble() ?? 0;
      return d.isFinite ? d : 0;
    }

    return ComparisonChange(
      value: parseDouble(json['value']),
      percentage: parseDouble(json['percentage']),
      trend: json['trend'] as String? ?? 'neutral',
    );
  }

  bool get isPositive => trend == 'up';
  bool get isNegative => trend == 'down';
}

/// Study streak information
class StudyStreak {
  final int current;
  final int longest;
  final bool isActiveToday;

  StudyStreak({
    this.current = 0,
    this.longest = 0,
    this.isActiveToday = false,
  });

  factory StudyStreak.fromJson(Map<String, dynamic> json) {
    return StudyStreak(
      current: json['current'] as int? ?? 0,
      longest: json['longest'] as int? ?? 0,
      isActiveToday: json['is_active_today'] as bool? ?? false,
    );
  }
}

/// Flashcard mastery statistics
class FlashcardMastery {
  final int total;
  final int mastered;
  final int learning;
  final int difficult;
  final double masteryPercentage;
  final int cardsDueToday;
  final String? nextStudySession;

  FlashcardMastery({
    this.total = 0,
    this.mastered = 0,
    this.learning = 0,
    this.difficult = 0,
    this.masteryPercentage = 0,
    this.cardsDueToday = 0,
    this.nextStudySession,
  });

  factory FlashcardMastery.fromJson(Map<String, dynamic> json) {
    return FlashcardMastery(
      total: json['total'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      learning: json['learning'] as int? ?? 0,
      difficult: json['difficult'] as int? ?? 0,
      masteryPercentage: (json['mastery_percentage'] as num?)?.toDouble() ?? 0,
      cardsDueToday: json['cards_due_today'] as int? ?? 0,
      nextStudySession: json['next_study_session'] as String?,
    );
  }
}

/// Quick stats for fast dashboard display
class QuickStats {
  final int flashcardsToday;
  final int flashcardsThisWeek;
  final int flashcardsThisMonth;
  final int flashcardsThisYear;
  final int examsToday;
  final int examsThisWeek;
  final int examsThisMonth;
  final double studyHoursToday;
  final double studyHoursThisWeek;
  final double studyHoursThisMonth;
  final int cardsDueToday;
  final int streakDays;

  QuickStats({
    this.flashcardsToday = 0,
    this.flashcardsThisWeek = 0,
    this.flashcardsThisMonth = 0,
    this.flashcardsThisYear = 0,
    this.examsToday = 0,
    this.examsThisWeek = 0,
    this.examsThisMonth = 0,
    this.studyHoursToday = 0,
    this.studyHoursThisWeek = 0,
    this.studyHoursThisMonth = 0,
    this.cardsDueToday = 0,
    this.streakDays = 0,
  });

  factory QuickStats.fromJson(Map<String, dynamic> json) {
    return QuickStats(
      flashcardsToday: json['flashcards_today'] as int? ?? 0,
      flashcardsThisWeek: json['flashcards_this_week'] as int? ?? 0,
      flashcardsThisMonth: json['flashcards_this_month'] as int? ?? 0,
      flashcardsThisYear: json['flashcards_this_year'] as int? ?? 0,
      examsToday: json['exams_today'] as int? ?? 0,
      examsThisWeek: json['exams_this_week'] as int? ?? 0,
      examsThisMonth: json['exams_this_month'] as int? ?? 0,
      studyHoursToday: (json['study_hours_today'] as num?)?.toDouble() ?? 0,
      studyHoursThisWeek: (json['study_hours_this_week'] as num?)?.toDouble() ?? 0,
      studyHoursThisMonth: (json['study_hours_this_month'] as num?)?.toDouble() ?? 0,
      cardsDueToday: json['cards_due_today'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

/// Material counts (decks, exams, flashcards)
class MaterialCounts {
  final MaterialCount decks;
  final MaterialCount exams;
  final FlashcardCount flashcards;

  MaterialCounts({
    required this.decks,
    required this.exams,
    required this.flashcards,
  });

  factory MaterialCounts.fromJson(Map<String, dynamic> json) {
    return MaterialCounts(
      decks: MaterialCount.fromJson(json['decks'] as Map<String, dynamic>? ?? {}),
      exams: MaterialCount.fromJson(json['exams'] as Map<String, dynamic>? ?? {}),
      flashcards: FlashcardCount.fromJson(json['flashcards'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Material count (total, own, shared)
class MaterialCount {
  final int total;
  final int own;
  final int shared;

  MaterialCount({
    this.total = 0,
    this.own = 0,
    this.shared = 0,
  });

  factory MaterialCount.fromJson(Map<String, dynamic> json) {
    return MaterialCount(
      total: json['total'] as int? ?? 0,
      own: json['own'] as int? ?? 0,
      shared: json['shared'] as int? ?? 0,
    );
  }
}

/// Flashcard count
class FlashcardCount {
  final int total;
  final int studied;

  FlashcardCount({
    this.total = 0,
    this.studied = 0,
  });

  factory FlashcardCount.fromJson(Map<String, dynamic> json) {
    return FlashcardCount(
      total: json['total'] as int? ?? 0,
      studied: json['studied'] as int? ?? 0,
    );
  }
}