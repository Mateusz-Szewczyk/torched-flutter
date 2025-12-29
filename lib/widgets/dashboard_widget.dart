import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import 'learning_calendar_widget.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  final DashboardService _dashboardService = DashboardService();
  DashboardData? _data;
  bool _isLoading = true;
  String? _error;
  DateTime _lastRefreshTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _dashboardService.fetchDashboardData();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Refined Breakpoints
    final isMobile = screenWidth < 700;
    final isTablet = screenWidth >= 700 && screenWidth < 1100;
    final isDesktop = screenWidth >= 1100;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _data == null) {
      return const Center(child: Text('Error loading dashboard'));
    }

    final extendedSummary = _data!.getExtendedSummary();
    final recentExams = _getRecentExams();

    // Increased max width for a more expansive "Dashboard" feel
    final maxContentWidth = isDesktop ? 1400.0 : double.infinity;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: isMobile ? 16.0 : 32.0,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxContentWidth),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. Header
                                    _DashboardHeader(extendedSummary: extendedSummary),
                                    const SizedBox(height: 24),

                                    // 2. Top Section: Goal (Left) + Actions (Right)
                                    _TopSection(
                                      flashcardsDone: extendedSummary.flashcardsToday,
                                      flashcardsGoal: 10,
                                      onFlashcardsTap: () => context.go('/flashcards'),
                                      onTestsTap: () => context.go('/tests'),
                                      isMobile: isMobile,
                                    ),

                                    const SizedBox(height: 24),

                                    // 3. Main Content: Exams (Left Sidebar) + Calendar (Main Stage)
                                    _MainContentSection(
                                      recentExams: recentExams,
                                      lastRefreshTime: _lastRefreshTime,
                                      isMobile: isMobile,
                                      isTablet: isTablet,
                                    ),

                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRecentExams() {
    if (_data == null || _data!.examResults.isEmpty) return [];
    final sortedExams = List<ExamResult>.from(_data!.examResults);
    sortedExams.sort((a, b) {
      final dateA = DateTime.tryParse(a.startedAt) ?? DateTime(1970);
      final dateB = DateTime.tryParse(b.startedAt) ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    // Take more items to fill the vertical space better
    final recent = sortedExams.take(8).toList();

    return recent.map((e) {
      return {
        'name': e.examName.isNotEmpty ? e.examName : 'Exam #${e.examId}',
        'score': e.score.toInt(),
        'date': DateTime.tryParse(e.startedAt) ?? DateTime.now(),
      };
    }).toList();
  }
}

// ============================================================================
// 1. HEADER
// ============================================================================
class _DashboardHeader extends StatelessWidget {
  final ExtendedDashboardSummary extendedSummary;
  const _DashboardHeader({required this.extendedSummary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Learning Dashboard',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (extendedSummary.studyStreak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF332200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${extendedSummary.studyStreak} Days',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 2. TOP SECTION (Goal & Actions)
// ============================================================================
class _TopSection extends StatelessWidget {
  final int flashcardsDone;
  final int flashcardsGoal;
  final VoidCallback onFlashcardsTap;
  final VoidCallback onTestsTap;
  final bool isMobile;

  const _TopSection({
    required this.flashcardsDone,
    required this.flashcardsGoal,
    required this.onFlashcardsTap,
    required this.onTestsTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          SizedBox(
            height: 140,
            child: _GoalCard(done: flashcardsDone, goal: flashcardsGoal)
          ),
          const SizedBox(height: 16),
          _ActionButtons(
            onStudy: onFlashcardsTap,
            onExam: onTestsTap,
            isMobile: true,
          ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _GoalCard(done: flashcardsDone, goal: flashcardsGoal),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: _ActionButtons(
              onStudy: onFlashcardsTap,
              onExam: onTestsTap,
              isMobile: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int done;
  final int goal;

  const _GoalCard({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (done / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  color: colorScheme.onSurface.withOpacity(0.1),
                  strokeWidth: 8,
                ),
                CircularProgressIndicator(
                  value: progress,
                  color: Colors.green,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                ),
                if (done >= goal)
                  const Icon(Icons.check, color: Colors.green, size: 32),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Daily Goal',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$done',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      ' / $goal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Cards Reviewed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onStudy;
  final VoidCallback onExam;
  final bool isMobile;

  const _ActionButtons({
    required this.onStudy,
    required this.onExam,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: onStudy,
                icon: const Icon(Icons.style, size: 24),
                label: const Text('Cards', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: onExam,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Exams', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStudy,
              icon: const Icon(Icons.style, size: 28),
              label: const Text('Study Flashcards', style: TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onExam,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Take Exam', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. MAIN CONTENT (Exams + Calendar)
// ============================================================================
class _MainContentSection extends StatelessWidget {
  final List<Map<String, dynamic>> recentExams;
  final DateTime lastRefreshTime;
  final bool isMobile;
  final bool isTablet;

  const _MainContentSection({
    required this.recentExams,
    required this.lastRefreshTime,
    required this.isMobile,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          _CalendarContainer(lastRefreshTime: lastRefreshTime, minHeight: 400),
          const SizedBox(height: 24),
          _RecentExamsList(exams: recentExams),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isTablet ? 220 : 280,
          child: _RecentExamsList(exams: recentExams),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _CalendarContainer(
            lastRefreshTime: lastRefreshTime,
            minHeight: 600,
          ),
        ),
      ],
    );
  }
}

class _CalendarContainer extends StatelessWidget {
  final DateTime lastRefreshTime;
  final double minHeight;

  const _CalendarContainer({required this.lastRefreshTime, required this.minHeight});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      child: LearningCalendarWidget(
        key: ValueKey(lastRefreshTime),
        expandToFill: true,
        sideNavigationButtons: isDesktop,
        largeNavigationButtons: isDesktop,
      ),
    );
  }
}

class _RecentExamsList extends StatelessWidget {
  final List<Map<String, dynamic>> exams;

  const _RecentExamsList({required this.exams});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exams',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (exams.isEmpty)
            Text('No exams yet', style: theme.textTheme.bodyMedium)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final exam = exams[index];
                final score = exam['score'] as int;
                final date = exam['date'] as DateTime;

                Color statusColor = Colors.red;
                if (score >= 80) statusColor = Colors.green;
                else if (score >= 50) statusColor = Colors.orange;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: statusColor),
                        const SizedBox(width: 8),
                        Text(
                          '$score%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d').format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exam['name'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}