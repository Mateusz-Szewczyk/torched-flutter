import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Dashboard Service - fetches user statistics and study data
/// Equivalent to dashboard API calls in React app

class DashboardService {
  final ApiService _api = ApiService();

  /// Fetch all dashboard data for the logged-in user
  Future<DashboardData?> fetchDashboardData() async {
    try {
      final response = await _api.ragGet('/dashboard/');

      if (response.statusCode == 200 && response.data != null) {
        return DashboardData.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      return null;
    }
  }
}

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

  DashboardData({
    required this.studyRecords,
    required this.userFlashcards,
    required this.studySessions,
    required this.examResults,
    required this.sessionDurations,
    required this.examDailyAverage,
    required this.flashcardDailyAverage,
    required this.deckNames,
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
    );
  }

  /// Calculate summary statistics
  DashboardSummary getSummary() {
    // Total study time
    final totalStudyTime = sessionDurations.fold<double>(
      0, (sum, session) => sum + session.durationHours,
    );

    // Average exam score
    final validExams = examResults.where((e) => e.score >= 0 && e.score <= 100);
    final averageExamScore = validExams.isEmpty
        ? 0.0
        : validExams.fold<double>(0, (sum, e) => sum + e.score) / validExams.length;

    // Total flashcards studied
    final totalFlashcards = studyRecords.length;

    // Calculate study streak
    final studyStreak = _calculateStudyStreak();

    return DashboardSummary(
      totalStudyTime: totalStudyTime,
      averageExamScore: averageExamScore,
      totalFlashcards: totalFlashcards,
      studyStreak: studyStreak,
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

