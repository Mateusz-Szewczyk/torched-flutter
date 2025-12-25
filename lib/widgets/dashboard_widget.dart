import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/dashboard_service.dart';

/// Mobile-First Dashboard Widget - TorchED Learning Dashboard
/// Designed for phone first, then responsive for tablet/web

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
  bool _showFilters = false;

  // Filter state
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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

    if (_isLoading) {
      return _buildLoadingState(colorScheme);
    }

    if (_error != null || _data == null) {
      return _buildErrorState(colorScheme);
    }

    final summary = _data!.getSummary();

    // Mobile-first: everything in a vertical scroll
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Section: Welcome + Streak + Today's Goal
            _HeroOverviewSection(
              summary: summary,
              userName: 'Learner',
            ),

            const SizedBox(height: 20),

            // 2. Today's Goal & Next Action (most important for mobile!)
            _TodayGoalCard(summary: summary),

            const SizedBox(height: 16),

            _NextActionCard(
              onFlashcardsTap: () => context.go('/flashcards'),
              onTestsTap: () => context.go('/tests'),
            ),

            const SizedBox(height: 24),

            // 3. Weekly Summary (moved higher for quick overview)
            _WeeklySummarySection(data: _data!),

            const SizedBox(height: 24),

            // 4. Stats Cards (mobile: stack, desktop: 3 column grid)
            _buildStatCardsSection(context, summary),

            const SizedBox(height: 24),

            // 5. Milestones/Achievements Strip (horizontal scroll)
            _MilestoneStrip(summary: summary),

            const SizedBox(height: 24),

            // 6. Filter Bar (collapsible)
            _FilterBar(
              isExpanded: _showFilters,
              onToggle: () => setState(() => _showFilters = !_showFilters),
              startDate: _filterStartDate,
              endDate: _filterEndDate,
              onStartDateChanged: (d) => setState(() => _filterStartDate = d),
              onEndDateChanged: (d) => setState(() => _filterEndDate = d),
              onClear: () => setState(() {
                _filterStartDate = null;
                _filterEndDate = null;
              }),
            ),

            const SizedBox(height: 24),

            // 7. Exam Analysis Section
            if (_data!.examResults.isNotEmpty)
              _ExamAnalysisSection(data: _data!),

            const SizedBox(height: 24),

            // 8. Flashcard Analysis Section
            if (_data!.studyRecords.isNotEmpty)
              _FlashcardAnalysisSection(data: _data!),

            const SizedBox(height: 24),

            // 9. Cookbook/Tips Section
            const _CookbookSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withAlpha(30),
                  colorScheme.primary.withAlpha(10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(180),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preparing your learning journey',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(120),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please check your connection and try again',
              style: TextStyle(
                color: colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardsSection(BuildContext context, DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile-first: stack cards, on wider screens use grid
        final isWide = constraints.maxWidth > 600;

        final cards = [
          _MotivationalStatCard(
            icon: Icons.timer_outlined,
            iconColor: Colors.blue,
            title: 'Total Study Time',
            value: summary.totalStudyTime.toStringAsFixed(1),
            unit: 'hours',
            subtitle: 'Time well invested',
            progress: (summary.totalStudyTime / 100).clamp(0.0, 1.0),
            progressColor: Colors.blue,
          ),
          _MotivationalStatCard(
            icon: Icons.emoji_events,
            iconColor: Colors.amber.shade700,
            title: 'Average Score',
            value: '${summary.averageExamScore.toStringAsFixed(0)}',
            unit: '%',
            subtitle: summary.averageExamScore >= 80 ? 'Excellent! 🌟' : 'Keep improving!',
            progress: summary.averageExamScore / 100,
            progressColor: Colors.amber.shade700,
          ),
          _MotivationalStatCard(
            icon: Icons.style,
            iconColor: Colors.green,
            title: 'Cards Studied',
            value: '${summary.totalFlashcards}',
            unit: 'cards',
            subtitle: 'Knowledge gained',
            progress: (summary.totalFlashcards / 500).clamp(0.0, 1.0),
            progressColor: Colors.green,
          ),
        ];

        if (isWide) {
          // Desktop: 3 column grid
          return GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: cards,
          );
        } else {
          // Mobile: vertical stack with full width cards
          return Column(
            children: cards.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            )).toList(),
          );
        }
      },
    );
  }
}

// ============================================================================
// HERO OVERVIEW SECTION
// ============================================================================

class _HeroOverviewSection extends StatelessWidget {
  final DashboardSummary summary;
  final String userName;

  const _HeroOverviewSection({
    required this.summary,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final greeting = _getGreeting();
    final motivationalMessage = _getMotivationalMessage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withAlpha(150),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wb_sunny_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivationalMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Streak highlight
          if (summary.studyStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withAlpha(200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.studyStreak} Day Streak!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        "You're on fire! Keep going!",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! ☀️';
    if (hour < 17) return 'Good Afternoon! 🌤️';
    return 'Good Evening! 🌙';
  }

  String _getMotivationalMessage() {
    if (summary.studyStreak >= 7) {
      return "Amazing streak! You're building great habits!";
    } else if (summary.studyStreak >= 3) {
      return "Great momentum! Keep the streak alive!";
    } else if (summary.totalFlashcards > 0) {
      return "Ready to continue your learning journey?";
    } else {
      return "Let's start your learning journey today!";
    }
  }
}

// ============================================================================
// TODAY'S GOAL CARD
// ============================================================================

class _TodayGoalCard extends StatelessWidget {
  final DashboardSummary summary;

  const _TodayGoalCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Simple goal: review at least 10 flashcards or complete 1 exam
    final dailyGoal = 10;
    final todayProgress = (summary.totalFlashcards % dailyGoal).clamp(0, dailyGoal);
    final progressPercent = todayProgress / dailyGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Goal",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressPercent >= 1
                      ? Colors.green.withAlpha(30)
                      : colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  progressPercent >= 1 ? '✓ Complete!' : '$todayProgress/$dailyGoal',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: progressPercent >= 1 ? Colors.green : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(
                progressPercent >= 1 ? Colors.green : colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progressPercent >= 1
                ? "Great job! You've hit your daily goal! 🎉"
                : 'Review ${dailyGoal - todayProgress} more flashcards to reach your goal',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NEXT ACTION CARD - Most important CTA for mobile users
// ============================================================================

class _NextActionCard extends StatelessWidget {
  final VoidCallback onFlashcardsTap;
  final VoidCallback onTestsTap;

  const _NextActionCard({
    required this.onFlashcardsTap,
    required this.onTestsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withAlpha(200),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚀 Ready to Learn?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Continue where you left off',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withAlpha(200),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.style,
                  label: 'Flashcards',
                  onTap: onFlashcardsTap,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionButton(
                  icon: Icons.quiz_outlined,
                  label: 'Tests',
                  onTap: onTestsTap,
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isPrimary
          ? colorScheme.onPrimary
          : colorScheme.onPrimary.withAlpha(30),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(
                icon,
                color: isPrimary ? colorScheme.primary : colorScheme.onPrimary,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? colorScheme.primary : colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MOTIVATIONAL STAT CARD
// ============================================================================

class _MotivationalStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final double progress;
  final Color progressColor;

  const _MotivationalStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: progressColor.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w500,
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

// ============================================================================
// MILESTONE STRIP - Horizontal scrolling achievements
// ============================================================================

class _MilestoneStrip extends StatelessWidget {
  final DashboardSummary summary;

  const _MilestoneStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final milestones = [
      _Milestone('🎯', 'First Card', summary.totalFlashcards >= 1, 'Review 1 flashcard'),
      _Milestone('📚', '10 Cards', summary.totalFlashcards >= 10, 'Review 10 flashcards'),
      _Milestone('🔥', '3 Day Streak', summary.studyStreak >= 3, 'Study 3 days in a row'),
      _Milestone('⭐', 'Week Warrior', summary.studyStreak >= 7, 'Study 7 days in a row'),
      _Milestone('🏆', 'Exam Ace', summary.averageExamScore >= 80, 'Score 80%+ on exams'),
      _Milestone('💯', 'Perfectionist', summary.averageExamScore >= 95, 'Score 95%+ average'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '🏅 Achievements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: milestones.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final m = milestones[index];
              return Container(
                width: 90,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: m.achieved
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: m.achieved
                        ? colorScheme.primary.withAlpha(80)
                        : colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m.emoji,
                      style: TextStyle(
                        fontSize: 28,
                        color: m.achieved ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: m.achieved
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface.withAlpha(100),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Milestone {
  final String emoji;
  final String title;
  final bool achieved;
  final String description;

  _Milestone(this.emoji, this.title, this.achieved, this.description);
}

// ============================================================================
// FILTER BAR
// ============================================================================

class _FilterBar extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.isExpanded,
    required this.onToggle,
    this.startDate,
    this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasFilters = startDate != null || endDate != null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Filters',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  // Date range pickers
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerButton(
                          label: 'From',
                          date: startDate,
                          onChanged: onStartDateChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerButton(
                          label: 'To',
                          date: endDate,
                          onChanged: onEndDateChanged,
                        ),
                      ),
                    ],
                  ),
                  if (hasFilters) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear Filters'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerButton({
    required this.label,
    this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: colorScheme.onSurface.withAlpha(150),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? '${date!.day}/${date!.month}/${date!.year}'
                    : label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: date != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXAM ANALYSIS SECTION
// ============================================================================

class _ExamAnalysisSection extends StatelessWidget {
  final DashboardData data;

  const _ExamAnalysisSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final scoreData = data.getExamScoreDistribution();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz_outlined, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                'Exam Analysis',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Simple score distribution
          Text(
            'Score Distribution',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(height: 12),
          if (scoreData.isEmpty)
            Text(
              'Complete some exams to see your score distribution',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(120),
              ),
            )
          else
            _SimpleBarChart(data: scoreData),
          const SizedBox(height: 16),
          // Recent exams
          Text(
            'Recent Exams',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(height: 8),
          ...data.examResults.take(3).map((exam) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exam.examName.isNotEmpty ? exam.examName : 'Exam',
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(exam.score).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${exam.score.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _getScoreColor(exam.score),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

// ============================================================================
// FLASHCARD ANALYSIS SECTION
// ============================================================================

class _FlashcardAnalysisSection extends StatelessWidget {
  final DashboardData data;

  const _FlashcardAnalysisSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final ratingDistribution = data.getFlashcardRatingDistribution();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.style, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Text(
                'Flashcard Analysis',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Rating distribution
          Text(
            'Performance Distribution',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(height: 12),
          if (ratingDistribution.isEmpty)
            Text(
              'Study some flashcards to see your performance',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(120),
              ),
            )
          else
            ...ratingDistribution.map((item) {
              final color = switch (item.rating) {
                'Hard' => Colors.red,
                'Good' => Colors.orange,
                'Easy' => Colors.green,
                _ => colorScheme.primary,
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        item.rating,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: item.percentage / 100,
                          minHeight: 12,
                          backgroundColor: color.withAlpha(30),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${item.percentage}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================================
// WEEKLY SUMMARY SECTION
// ============================================================================

class _WeeklySummarySection extends StatelessWidget {
  final DashboardData data;

  const _WeeklySummarySection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate weekly stats
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final weeklyFlashcards = data.studyRecords.where((r) {
      try {
        final date = DateTime.parse(r.reviewedAt);
        return date.isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    }).length;

    final weeklyExams = data.examResults.where((e) {
      try {
        final date = DateTime.parse(e.startedAt);
        return date.isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_view_week, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Text(
                'This Week',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WeeklyStatItem(
                  icon: Icons.style,
                  color: Colors.green,
                  value: '$weeklyFlashcards',
                  label: 'Cards Reviewed',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _WeeklyStatItem(
                  icon: Icons.quiz_outlined,
                  color: Colors.orange,
                  value: '$weeklyExams',
                  label: 'Exams Taken',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _WeeklyStatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(150),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COOKBOOK SECTION
// ============================================================================

class _CookbookSection extends StatefulWidget {
  const _CookbookSection();

  @override
  State<_CookbookSection> createState() => _CookbookSectionState();
}

class _CookbookSectionState extends State<_CookbookSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_outline, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learning Tips',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'How to get the most out of TorchED',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _TipItem(
                    icon: Icons.chat_bubble_outline,
                    title: 'Use AI Chat',
                    description: 'Ask AI to generate flashcards or exams from your study materials.',
                  ),
                  _TipItem(
                    icon: Icons.upload_file,
                    title: 'Upload Documents',
                    description: 'Upload PDFs and the AI will help you study the content.',
                  ),
                  _TipItem(
                    icon: Icons.schedule,
                    title: 'Study Daily',
                    description: 'Even 10-15 minutes daily is more effective than cramming.',
                  ),
                  _TipItem(
                    icon: Icons.psychology,
                    title: 'Spaced Repetition',
                    description: 'Review flashcards regularly - the app optimizes review timing.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TipItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(150),
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

// ============================================================================
// SIMPLE BAR CHART - No external dependencies
// ============================================================================

class _SimpleBarChart extends StatelessWidget {
  final List<ScoreDistribution> data;

  const _SimpleBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter to show only relevant score ranges (combined)
    final combinedData = [
      _ChartItem('0-40', data.take(5).fold(0, (sum, item) => sum + item.count)),
      _ChartItem('41-60', data.length > 5 && data.length > 6 ? data[5].count + (data.length > 6 ? data[6].count : 0) : 0),
      _ChartItem('61-80', data.length > 7 && data.length > 8 ? data[7].count + (data.length > 8 ? data[8].count : 0) : 0),
      _ChartItem('81-100', data.length > 9 ? data[9].count + (data.length > 10 ? data[10].count : 0) : 0),
    ];

    final maxCount = combinedData.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return Column(
      children: combinedData.map((item) {
        final percentage = maxCount > 0 ? item.count / maxCount : 0.0;
        final color = switch (item.label) {
          '0-40' => Colors.red,
          '41-60' => Colors.orange,
          '61-80' => Colors.amber.shade700,
          '81-100' => Colors.green,
          _ => Colors.grey,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 55,
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 18,
                    backgroundColor: color.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 30,
                child: Text(
                  '${item.count}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChartItem {
  final String label;
  final int count;

  _ChartItem(this.label, this.count);
}
