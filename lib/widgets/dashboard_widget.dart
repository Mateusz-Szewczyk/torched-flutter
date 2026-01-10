import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/dimens.dart';
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

    // Layout Constants from AppDimens
    final maxContentWidth = AppDimens.maxContentWidth;
    final horizontalPadding = isDesktop 
        ? AppDimens.screenPaddingDesktop 
        : (isTablet ? AppDimens.screenPaddingTablet : AppDimens.screenPaddingMobile);

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
                                vertical: isMobile ? AppDimens.paddingXL : AppDimens.paddingXXL,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxContentWidth),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. Header
                                    _DashboardHeader(extendedSummary: extendedSummary),
                                    const SizedBox(height: AppDimens.gapXL),

                                    // 2. Top Section: Goal & Actions
                                    _TopSection(
                                      flashcardsDone: extendedSummary.flashcardsToday,
                                      flashcardsGoal: extendedSummary.cardsDueToday,
                                      onFlashcardsTap: () => context.go('/flashcards'),
                                      onTestsTap: () => context.go('/tests'),
                                      isMobile: isMobile,
                                    ),
                                    
                                    const SizedBox(height: AppDimens.gapXL),

                                    // 3. Main Content: Exams (Left Sidebar) + Calendar (Main Stage)
                                    _MainContentSection(
                                      recentExams: recentExams,
                                      lastRefreshTime: _lastRefreshTime,
                                      isMobile: isMobile,
                                      isTablet: isTablet,
                                    ),

                                    const SizedBox(height: AppDimens.sectionGap),
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
          Tooltip(
            message: 'Longest streak: ${extendedSummary.streakLongest} days',
            child: Semantics(
              label: 'Study streak. Current streak: ${extendedSummary.studyStreak} days. Best streak: ${extendedSummary.streakLongest} days.',
              container: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingL, 
                  vertical: AppDimens.paddingS,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF332200),
                  borderRadius: BorderRadius.circular(AppDimens.radiusXL),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: AppDimens.iconM),
                    const SizedBox(width: AppDimens.gapS),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${extendedSummary.studyStreak} Days',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (extendedSummary.streakLongest > extendedSummary.studyStreak)
                          Text(
                            'Best: ${extendedSummary.streakLongest}',
                            style: TextStyle(
                              color: Colors.orange.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
            height: 160,
            child: _DailyGoalCard(done: flashcardsDone, goal: flashcardsGoal)
          ),
          const SizedBox(height: AppDimens.gapM),
          _ActionButtons(
            onStudy: onFlashcardsTap,
            onExam: onTestsTap,
            isMobile: true,
            cardsDue: flashcardsGoal,
          ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _DailyGoalCard(done: flashcardsDone, goal: flashcardsGoal),
          ),
          const SizedBox(width: AppDimens.gapXL),
          Expanded(
            flex: 4,
            child: _ActionButtons(
              onStudy: onFlashcardsTap,
              onExam: onTestsTap,
              isMobile: false,
              cardsDue: flashcardsGoal,
            ),
          ),
        ],
      ),
    );
  }
}



class _DailyGoalCard extends StatelessWidget {
  final int done;
  final int goal;

  const _DailyGoalCard({
    required this.done,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Calculate progress for the ring
    // Avoid division by zero, cap at 1.0 for the ring (or let it go over?)
    final progress = goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingXL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusXXL),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.track_changes, color: colorScheme.primary, size: AppDimens.iconM),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              // Progress Ring
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      color: colorScheme.primary,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.gapL),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$done',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '/$goal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Cards reviewed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onStudy;
  final VoidCallback onExam;
  final bool isMobile;
  final int cardsDue;

  const _ActionButtons({
    required this.onStudy,
    required this.onExam,
    required this.isMobile,
    required this.cardsDue,
  });

  @override
  Widget build(BuildContext context) {
    final studyCard = _buildStudyCard(context);
    final examCard = _buildExamCard(context);

    if (isMobile) {
      return Row(
        children: [
          Expanded(child: SizedBox(height: 100, child: studyCard)),
          const SizedBox(width: AppDimens.gapM),
          Expanded(child: SizedBox(height: 100, child: examCard)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: studyCard),
        const SizedBox(height: AppDimens.gapM),
        Expanded(child: examCard),
      ],
    );
  }

  Widget _buildStudyCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDue = cardsDue > 0;
    
    // Dynamic styling for Study Card
    // Dynamic styling for Study Card (White/Neutral with Orange accent)
    final bgColor = colorScheme.surfaceContainer;
    final fgColor = hasDue ? colorScheme.primary : colorScheme.onSurface;
    final subColor = colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStudy,
        borderRadius: BorderRadius.circular(AppDimens.radiusXXL),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusXXL),
            border: hasDue ? Border.all(color: colorScheme.primary, width: 2) : Border.all(color: colorScheme.outlineVariant),
            // Add subtle shadow if urgent
            boxShadow: hasDue ? [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Semantics(
            label: hasDue ? 'Study Flashcards. $cardsDue cards due. Urgent.' : 'Study Flashcards',
            button: true,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        hasDue ? Icons.access_time_filled : Icons.style,
                        color: fgColor,
                        size: AppDimens.iconL,
                      ),
                      if (hasDue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2), // Updated to withValues
                            borderRadius: BorderRadius.circular(AppDimens.radiusM),
                          ),
                          child: Text(
                            'Urgent',
                            style: TextStyle(
                              color: fgColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    hasDue ? '$cardsDue Due' : 'Flashcards',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXS),
                  Text(
                    hasDue ? 'Study Now' : 'Review Deck',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExam,
        borderRadius: BorderRadius.circular(AppDimens.radiusXXL),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusXXL),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Semantics(
            label: 'Exams. Take or Create exams.',
            button: true,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, color: colorScheme.onSurface, size: AppDimens.iconL),
                  const Spacer(),
                  Text(
                    'Exams',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXS),
                  Text(
                    'Take or Create',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          const SizedBox(height: AppDimens.gapXL),
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
        const SizedBox(width: AppDimens.gapXL),
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
      padding: const EdgeInsets.all(AppDimens.paddingXL),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exams',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimens.gapL),
          if (exams.isEmpty)
            Text('No exams yet', style: theme.textTheme.bodyMedium)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppDimens.gapXL),
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
                        Icon(Icons.circle, size: AppDimens.paddingS, color: statusColor),
                        const SizedBox(width: AppDimens.gapS),
                        Text(
                          '$score%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gapXS),
                    Text(
                      DateFormat('MMM d').format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXS / 2),
                    Text(
                      exam['name'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
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