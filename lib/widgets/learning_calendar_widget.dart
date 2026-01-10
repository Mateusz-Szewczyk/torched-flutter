import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/flashcards_provider.dart';
import '../models/models.dart';
import '../theme/dimens.dart';

/// Learning Calendar Widget - GitHub-style contribution graph
/// Shows study history and scheduled flashcard reviews
class LearningCalendarWidget extends StatefulWidget {
  /// If true, the calendar expands to fill available width
  final bool expandToFill;

  /// If true, navigation buttons are placed on the sides (desktop only)
  final bool sideNavigationButtons;

  /// If true, navigation buttons are larger (desktop only)
  final bool largeNavigationButtons;

  const LearningCalendarWidget({
    super.key,
    this.expandToFill = false,
    this.sideNavigationButtons = false,
    this.largeNavigationButtons = false,
  });

  @override
  State<LearningCalendarWidget> createState() => _LearningCalendarWidgetState();
}

/// Individual calendar cell widget for better separation and hover support
class _CalendarCell extends StatefulWidget {
  final int? dayNumber;
  final Color backgroundColor;
  final bool isToday;
  final double cellSize;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  /// Tooltip message for desktop hover (e.g., "5 contributions on Dec 29")
  final String? tooltipMessage;
  /// If true, shows split color (half green, half red/blue) for mixed states
  final bool isSplit;
  final Color? splitColor;

  const _CalendarCell({
    this.dayNumber,
    required this.backgroundColor,
    required this.isToday,
    required this.cellSize,
    this.onTap,
    required this.colorScheme,
    this.tooltipMessage,
    this.isSplit = false,
    this.splitColor,
  });

  @override
  State<_CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<_CalendarCell> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Pulse animation for "today" indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isToday) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CalendarCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isToday && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isToday && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate text color based on background luminance
    final textColor = widget.backgroundColor.computeLuminance() > 0.5
        ? Colors.black54
        : Colors.white70;

    final fontSize = widget.cellSize < 20 ? widget.cellSize * 0.5 : widget.cellSize * 0.38;

    Widget cellWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: widget.cellSize,
              height: widget.cellSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: widget.isToday
                    ? Border.all(
                        color: widget.colorScheme.primary,
                        width: _pulseAnimation.value,
                      )
                    : _isHovered
                        ? Border.all(
                            color: widget.colorScheme.onSurface.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                boxShadow: widget.isToday
                    ? [
                        BoxShadow(
                          color: widget.colorScheme.primary.withValues(alpha: 0.3 * (2 - _pulseAnimation.value)),
                          blurRadius: 4 * _pulseAnimation.value,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    // Diagonal gradient for split states (premium look)
                    if (widget.isSplit && widget.splitColor != null)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _isHovered
                                  ? Color.lerp(widget.backgroundColor, Colors.white, 0.15)!
                                  : widget.backgroundColor,
                              _isHovered
                                  ? Color.lerp(widget.splitColor!, Colors.white, 0.15)!
                                  : widget.splitColor!,
                            ],
                            stops: const [0.45, 0.55],
                          ),
                        ),
                      )
                    else
                      Container(
                        color: _isHovered
                            ? Color.lerp(widget.backgroundColor, Colors.white, 0.15)
                            : widget.backgroundColor,
                      ),

                    // Day number on top
                    if (widget.dayNumber != null)
                      Center(
                        child: Text(
                          '${widget.dayNumber}',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltipMessage != null && widget.tooltipMessage!.isNotEmpty) {
      cellWidget = Tooltip(
        message: widget.tooltipMessage!,
        waitDuration: const Duration(milliseconds: 500),
        preferBelow: true,
        decoration: BoxDecoration(
          color: widget.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: AppDimens.paddingS,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: widget.colorScheme.onSurface,
          fontSize: 12,
        ),
        child: cellWidget,
      );
    }

    return cellWidget;
  }
}


class _LearningCalendarWidgetState extends State<LearningCalendarWidget> {
  final DashboardService _dashboardService = DashboardService();

  CalendarData? _calendarData;
  bool _isLoading = true;
  String? _error;

  // Current displayed month
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _dashboardService.fetchCalendarData(
        monthsBack: 3,
        monthsForward: 2,
      );

      if (data != null) {
        setState(() {
          _calendarData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load calendar data';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Calendar] Error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    final now = DateTime.now();
    final minMonth = DateTime(now.year, now.month - 3, 1);

    if (_currentMonth.isAfter(minMonth)) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      });
    }
  }

  void _nextMonth() {
    final now = DateTime.now();
    final maxMonth = DateTime(now.year, now.month + 2, 1);

    if (_currentMonth.isBefore(maxMonth)) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      });
    }
  }

  // Helper to remove time component for accurate date comparison
  DateTime _stripTime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 380;
    final isDesktop = screenWidth >= 900;

    final double? maxCalendarWidth;
    if (widget.expandToFill) {
      maxCalendarWidth = isDesktop ? 900.0 : double.infinity;
    } else {
      maxCalendarWidth = isDesktop ? 420.0 : (isMobile ? double.infinity : 460.0);
    }

    return Center(
      child: Container(
        constraints: maxCalendarWidth != null
            ? BoxConstraints(maxWidth: maxCalendarWidth)
            : null,
        margin: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppDimens.gapS,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
          border: widget.expandToFill
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, colorScheme, isMobile, isSmallMobile, isDesktop),
            if (_isLoading)
              _buildLoadingState(colorScheme)
            else if (_error != null)
              _buildErrorState(colorScheme)
            else if (_calendarData != null)
              widget.sideNavigationButtons && isDesktop
                  ? _buildCalendarWithSideNav(context, colorScheme, isMobile, isSmallMobile)
                  : _buildCalendarContent(context, colorScheme, isMobile, isSmallMobile),
            if (_calendarData != null && !_isLoading)
              _buildLegend(context, colorScheme, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarWithSideNav(
    BuildContext context,
    ColorScheme colorScheme,
    bool isMobile,
    bool isSmallMobile,
  ) {
    final buttonSize = widget.largeNavigationButtons ? 56.0 : 48.0;
    final iconSize = widget.largeNavigationButtons ? 32.0 : 24.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingL, 
        vertical: AppDimens.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(buttonSize / 2),
            child: InkWell(
              onTap: _previousMonth,
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(color: colorScheme.outlineVariant),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_left, size: iconSize, color: colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildCalendarContent(context, colorScheme, isMobile, isSmallMobile),
          ),
          const SizedBox(width: 24),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(buttonSize / 2),
            child: InkWell(
              onTap: _nextMonth,
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(color: colorScheme.outlineVariant),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, size: iconSize, color: colorScheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile, bool isDesktop) {
    final monthName = _getMonthName(_currentMonth.month);
    final scheduledCount = _getScheduledCountForMonth();
    final showNavButtons = !widget.sideNavigationButtons || !isDesktop;

    return Container(
      padding: EdgeInsets.all(isMobile ? AppDimens.paddingM : (isDesktop ? AppDimens.paddingM : AppDimens.paddingL)),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusS)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: TextStyle(
                  fontSize: isDesktop ? 13 : (isMobile ? 14 : 15),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (_calendarData != null)
                 Text(
                    '${_calendarData!.stats.totalFlashcardsYear} this year',
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : (isDesktop ? 8 : 12)),

          if (showNavButtons)
            Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(Icons.chevron_left, _previousMonth, colorScheme, isDesktop: isDesktop),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? AppDimens.paddingL : 0),
                  child: Column(
                    children: [
                      Text(
                        isSmallMobile || isDesktop
                            ? '${monthName.substring(0, 3)} ${_currentMonth.year}'
                            : '$monthName ${_currentMonth.year}',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (scheduledCount > 0)
                        Text(
                          '$scheduledCount scheduled',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildNavButton(Icons.chevron_right, _nextMonth, colorScheme, isDesktop: isDesktop),
              ],
            )
          else
            Column(
              children: [
                Text(
                  isSmallMobile || isDesktop
                      ? '${monthName.substring(0, 3)} ${_currentMonth.year}'
                      : '$monthName ${_currentMonth.year}',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (scheduledCount > 0)
                  Text(
                    '$scheduledCount scheduled',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, ColorScheme colorScheme, {bool isDesktop = false}) {
    final buttonSize = isDesktop ? 48.0 : 36.0;
    final iconSize = isDesktop ? 32.0 : 22.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimens.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
          ),
          child: Icon(icon, size: iconSize, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  int _getScheduledCountForMonth() {
    if (_calendarData == null) return 0;
    int count = 0;
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    for (final entry in _calendarData!.scheduled.entries) {
      try {
        final date = DateTime.parse(entry.key);
        if (date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            date.isBefore(monthEnd.add(const Duration(days: 1)))) {
          count += entry.value.count;
        }
      } catch (_) {}
    }
    return count;
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: colorScheme.primary,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingXL),
      alignment: Alignment.center,
      child: Text('Error loading data', style: TextStyle(color: colorScheme.error)),
    );
  }

  Widget _buildCalendarContent(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    // Use current time from calendar data if available, else local time
    DateTime today;
    try {
      if (_calendarData?.generatedAt != null) {
        today = _stripTime(DateTime.parse(_calendarData!.generatedAt!));
      } else {
        today = _stripTime(DateTime.now());
      }
    } catch (_) {
      today = _stripTime(DateTime.now());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    const double cellSpacing = 3.0;
    final dayLabels = isDesktop
        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : isSmallMobile
            ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
            : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    if (widget.expandToFill) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - AppDimens.paddingXXL;
          final calculatedCellSize = (availableWidth - (cellSpacing * 6)) / 7;
          final cellSize = calculatedCellSize.clamp(16.0, 70.0);
          final totalGridWidth = (cellSize * 7) + (cellSpacing * 6);

          return _buildCalendarGrid(
            context,
            colorScheme,
            isMobile,
            isSmallMobile,
            isDesktop,
            cellSize,
            cellSpacing,
            totalGridWidth,
            dayLabels,
            firstWeekday,
            daysInMonth,
            today,
          );
        },
      );
    }

    final double cellSize;
    if (isDesktop) {
      cellSize = 16.0;
    } else if (isTablet) {
      cellSize = 20.0;
    } else if (isSmallMobile) {
      cellSize = 26.0;
    } else {
      cellSize = 30.0;
    }

    final totalGridWidth = (cellSize * 7) + (cellSpacing * 6);

    return _buildCalendarGrid(
      context,
      colorScheme,
      isMobile,
      isSmallMobile,
      isDesktop,
      cellSize,
      cellSpacing,
      totalGridWidth,
      dayLabels,
      firstWeekday,
      daysInMonth,
      today,
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    ColorScheme colorScheme,
    bool isMobile,
    bool isSmallMobile,
    bool isDesktop,
    double cellSize,
    double cellSpacing,
    double totalGridWidth,
    List<String> dayLabels,
    int firstWeekday,
    int daysInMonth,
    DateTime today,
  ) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppDimens.paddingS : AppDimens.paddingM, 
          vertical: AppDimens.paddingS,
        ),
        constraints: widget.expandToFill
            ? null
            : BoxConstraints(maxWidth: totalGridWidth + AppDimens.paddingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: totalGridWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: dayLabels.asMap().entries.map((entry) {
                  final isLast = entry.key == 6;
                  return Container(
                    width: cellSize,
                    margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop && !widget.expandToFill ? 8 : (cellSize * 0.35).clamp(8.0, 12.0),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        letterSpacing: -0.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: cellSpacing + 2),
            ..._buildCalendarRows(
              context,
              colorScheme,
              firstWeekday,
              daysInMonth,
              today,
              cellSize,
              cellSpacing,
              isSmallMobile,
              totalGridWidth,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCalendarRows(
    BuildContext context,
    ColorScheme colorScheme,
    int firstWeekday,
    int daysInMonth,
    DateTime today, // Normalized today
    double cellSize,
    double cellSpacing,
    bool isSmallMobile,
    double totalGridWidth,
  ) {
    final rows = <Widget>[];
    var currentDay = 1;
    var currentWeekday = 1;

    final totalCells = (firstWeekday - 1) + daysInMonth;
    final numWeeks = (totalCells / 7).ceil();

    final emptyColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161B22)
        : const Color(0xFFEBEDF0);

    for (var week = 0; week < numWeeks; week++) {
      final cells = <Widget>[];

      for (var day = 0; day < 7; day++) {
        final isLast = day == 6;

        if (week == 0 && currentWeekday < firstWeekday) {
          cells.add(
            Container(
              width: cellSize,
              height: cellSize,
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              decoration: BoxDecoration(
                color: emptyColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
          currentWeekday++;
        } else if (currentDay <= daysInMonth) {
          final date = DateTime(_currentMonth.year, _currentMonth.month, currentDay);
          final dateString = _formatDateString(date);

          // Get Data
          final historyDay = _calendarData?.history[dateString];
          final scheduledDay = _calendarData?.scheduled[dateString];
          final overdueDay = _calendarData?.overdue[dateString];

          // Normalized Comparisons
          final isToday = date.isAtSameMomentAs(today);
          final isPast = date.isBefore(today);
          final isFuture = date.isAfter(today);

          // Check data presence
          final hasCompleted = historyDay != null && historyDay.count > 0;
          final hasScheduled = scheduledDay != null && scheduledDay.count > 0;
          // IMPORTANT: Overdue cards are now grouped under "today" in the `overdue` map by the backend.
          final hasOverdue = overdueDay != null && overdueDay.count > 0;

          // Visual State
          Color backgroundColor = emptyColor;
          Color? splitColor;
          bool isSplit = false;

          // 1. PAST: Only history matters (overdue is moved to today)
          if (isPast) {
            if (hasCompleted) {
              final intensity = _getIntensityLevel(historyDay!.count);
              backgroundColor = _getGitHubGreenColor(intensity);
            }
          }
          // 2. TODAY: Can have Completed, Overdue, and Scheduled
          else if (isToday) {
            // Priority: Overdue > Scheduled > Completed
            // If we have mixed states, we try to show a split.

            if (hasOverdue && hasCompleted) {
              // Split: Green (History) + Red (Overdue)
              isSplit = true;
              final intensity = _getIntensityLevel(historyDay!.count);
              backgroundColor = _getGitHubGreenColor(intensity);
              splitColor = Colors.red.shade700;
            } else if (hasOverdue) {
              // Only Overdue
              backgroundColor = Colors.red.shade700;
            } else if (hasScheduled && hasCompleted) {
              // Split: Green (History) + Blue (Due Today)
              isSplit = true;
              final intensity = _getIntensityLevel(historyDay!.count);
              backgroundColor = _getGitHubGreenColor(intensity);
              splitColor = _getGitHubBlueColor(_getIntensityLevel(scheduledDay!.count));
            } else if (hasScheduled) {
              // Only Scheduled (Due Today)
              backgroundColor = _getGitHubBlueColor(_getIntensityLevel(scheduledDay!.count));
            } else if (hasCompleted) {
              // Only Completed
              final intensity = _getIntensityLevel(historyDay!.count);
              backgroundColor = _getGitHubGreenColor(intensity);
            }
          }
          // 3. FUTURE: Only Scheduled matters
          else if (isFuture) {
            if (hasScheduled) {
              backgroundColor = _getGitHubBlueColor(_getIntensityLevel(scheduledDay!.count));
            }
          }

          // Tooltip logic
          String? tooltipMessage;
          final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthName = monthNames[date.month - 1];
          final dayNum = currentDay;

          if (isToday) {
            final completed = hasCompleted ? historyDay!.count : 0;
            final overdue = hasOverdue ? overdueDay!.count : 0;
            final due = hasScheduled ? scheduledDay!.count : 0;

            if (overdue > 0) {
              tooltipMessage = '⚠️ $overdue overdue';
              if (due > 0) tooltipMessage += ', $due due today';
              if (completed > 0) tooltipMessage += ', $completed done';
            } else if (due > 0) {
              tooltipMessage = '🔵 $due due today';
              if (completed > 0) tooltipMessage += ', $completed done';
            } else if (completed > 0) {
              tooltipMessage = '✓ $completed completed today';
            } else {
              tooltipMessage = 'No activity today';
            }
          } else if (isPast) {
            if (hasCompleted) {
              tooltipMessage = '✓ ${historyDay!.count} completed on $monthName $dayNum';
            } else {
              tooltipMessage = 'No activity on $monthName $dayNum';
            }
          } else if (isFuture) {
            if (hasScheduled) {
              tooltipMessage = '📅 ${scheduledDay!.count} scheduled for $monthName $dayNum';
            } else {
              tooltipMessage = 'No sessions scheduled';
            }
          }

          cells.add(
            Container(
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              child: _CalendarCell(
                dayNumber: dayNum,
                backgroundColor: backgroundColor,
                isToday: isToday,
                cellSize: cellSize,
                colorScheme: colorScheme,
                tooltipMessage: tooltipMessage,
                isSplit: isSplit,
                splitColor: splitColor,
                onTap: () => _showDayDetails(
                  context,
                  dateString,
                  historyDay,
                  scheduledDay,
                  overdueDay, // Pass overdue data
                  isPast,
                  isFuture,
                  isToday,
                ),
              ),
            ),
          );
          currentDay++;
        } else {
          cells.add(
            Container(
              width: cellSize,
              height: cellSize,
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              decoration: BoxDecoration(
                color: emptyColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
      }

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: cellSpacing),
          child: SizedBox(
            width: totalGridWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: cells,
            ),
          ),
        ),
      );
    }

    return rows;
  }

  int _getIntensityLevel(int count) {
    final maxCount = _calendarData?.stats.maxCount ?? 40;
    if (count <= 0) return 0;

    final ratio = count / (maxCount > 0 ? maxCount : 1);
    if (ratio <= 0.1) return 1;
    if (ratio <= 0.3) return 2;
    if (ratio <= 0.6) return 3;
    return 4;
  }

  Color _getGitHubGreenColor(int level) {
    switch (level) {
      case 0: return const Color(0xFFEBEDF0);
      case 1: return const Color(0xFF9BE9A8);
      case 2: return const Color(0xFF40C463);
      case 3: return const Color(0xFF30A14E);
      case 4: return const Color(0xFF216E39);
      default: return const Color(0xFFEBEDF0);
    }
  }

  Color _getGitHubBlueColor(int level) {
    switch (level) {
      case 0: return const Color(0xFFEBEDF0);
      case 1: return const Color(0xFFD1E6FF);
      case 2: return const Color(0xFF8EC3FF);
      case 3: return const Color(0xFF3B93FF);
      case 4: return const Color(0xFF0D65D6);
      default: return const Color(0xFFEBEDF0);
    }
  }

  Widget _buildLegend(BuildContext context, ColorScheme colorScheme, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final cellSizeLegend = isDesktop ? 8.0 : 10.0;
    final spacingLegend = isDesktop ? 1.0 : 1.5;
    final fontSize = isDesktop ? 9.0 : 10.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 8 : 12, right: isDesktop ? 12 : 16, left: isDesktop ? 12 : 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Less', style: TextStyle(fontSize: fontSize, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              ...List.generate(5, (index) => Container(
                width: cellSizeLegend,
                height: cellSizeLegend,
                margin: EdgeInsets.symmetric(horizontal: spacingLegend),
                decoration: BoxDecoration(
                  color: index == 0
                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : const Color(0xFFEBEDF0))
                    : _getGitHubGreenColor(index),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(width: 4),
              Text('More', style: TextStyle(fontSize: fontSize, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: cellSizeLegend,
                height: cellSizeLegend,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B93FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Scheduled', style: TextStyle(fontSize: fontSize, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: cellSizeLegend,
                height: cellSizeLegend,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Overdue', style: TextStyle(fontSize: fontSize, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDayDetails(
    BuildContext context,
    String dateString,
    CalendarDay? historyDay,
    CalendarDay? scheduledDay,
    CalendarDay? overdueDay,
    bool isPast,
    bool isFuture,
    bool isToday,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final hasOverdue = overdueDay != null && overdueDay.count > 0;
    final hasScheduled = scheduledDay != null && scheduledDay.count > 0;
    final hasHistory = historyDay != null && historyDay.count > 0;

    // Build the content widget (shared between dialog and sheet)
    Widget buildContent() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasOverdue
                      ? Colors.red.withValues(alpha: 0.1)
                      : (isPast
                          ? const Color(0xFF216E39).withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(AppDimens.radiusM),
                ),
                child: Icon(
                  hasOverdue
                      ? Icons.warning_amber_rounded
                      : (isPast ? Icons.history : (isToday ? Icons.today : Icons.event)),
                  color: hasOverdue
                      ? Colors.red.shade700
                      : (isPast ? const Color(0xFF216E39) : Colors.blue),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.gapM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(dateString),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isToday)
                      Text(
                        'Today',
                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              // Close button for desktop dialog
              if (!isMobile)
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapL),

          // Overdue Section (Priority for Today)
          if (isToday && hasOverdue) ...[
            _buildDetailSection(
              context,
              'Overdue',
              '${overdueDay!.count}',
              Icons.warning_amber_rounded,
              Colors.red.shade700,
            ),
            const SizedBox(height: AppDimens.gapS),
            ...overdueDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, false, true)),
            const SizedBox(height: AppDimens.gapL),
          ],

          // Due Today / Scheduled Section
          if (hasScheduled && (isToday || isFuture)) ...[
            _buildDetailSection(
              context,
              isToday ? 'Due Today' : 'Scheduled',
              '${scheduledDay!.count}',
              Icons.schedule,
              Colors.blue,
            ),
            const SizedBox(height: AppDimens.gapS),
            ...scheduledDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, true, false)),
            const SizedBox(height: AppDimens.gapL),
          ],

          // Completed Section (Lower priority in display)
          if (hasHistory) ...[
            _buildDetailSection(
              context,
              'Studied',
              '${historyDay!.count}',
              Icons.check_circle,
              const Color(0xFF216E39),
            ),
            const SizedBox(height: AppDimens.gapS),
            ...historyDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, false, false)),
          ],

          // No activity message
          if (!hasHistory && !hasOverdue && !hasScheduled)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.paddingXL),
                child: Text('No activity', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            ),
        ],
      );
    }

    if (isMobile) {
      // Mobile: Use Bottom Sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: colorScheme.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXL)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppDimens.paddingL),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                buildContent(),
              ],
            ),
          ),
        ),
      );
    } else {
      // Desktop/Tablet: Use centered Dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusXL),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 550),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingXL),
              child: buildContent(),
            ),
          ),
        ),
      );
    }
  }


  Widget _buildDetailSection(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeckRow(BuildContext context, DeckCount deck, ColorScheme colorScheme, bool isScheduled, bool isOverdue) {
    final Color accentColor;
    if (isOverdue) {
      accentColor = Colors.red.shade700;
    } else if (isScheduled) {
      accentColor = Colors.blue;
    } else {
      accentColor = const Color(0xFF216E39);
    }

    final bool canStudy = deck.id != null && (isScheduled || isOverdue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapXS),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        child: InkWell(
          onTap: canStudy ? () => _startStudySession(context, deck) : null,
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.paddingM,
              vertical: AppDimens.paddingM,
            ),
            decoration: BoxDecoration(
              color: canStudy 
                  ? accentColor.withValues(alpha: 0.08) 
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppDimens.radiusM),
              border: Border.all(
                color: canStudy 
                    ? accentColor.withValues(alpha: 0.3) 
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimens.gapM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (canStudy)
                        Text(
                          '${deck.count} cards ${isOverdue ? 'overdue' : 'due'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canStudy) ...[
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: accentColor,
                    size: AppDimens.iconL,
                  ),
                ] else ...[
                  Text(
                    '${deck.count}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startStudySession(BuildContext context, DeckCount deck) {
    // Close dialog/sheet
    Navigator.of(context).pop();
    // Start study session
    context.read<FlashcardsProvider>().startStudy(
      DeckInfo(
        id: deck.id!,
        name: deck.name,
        flashcardCount: deck.count,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    // Navigate to flashcards
    context.go('/flashcards');
  }


  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}