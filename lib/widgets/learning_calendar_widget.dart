import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

/// Learning Calendar Widget - GitHub-style contribution graph
/// Shows study history and scheduled flashcard reviews
/// Mobile-first design with improved contrast
class LearningCalendarWidget extends StatefulWidget {
  const LearningCalendarWidget({super.key});

  @override
  State<LearningCalendarWidget> createState() => _LearningCalendarWidgetState();
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
        monthsForward: 2, // Fetch 2 months forward to ensure scheduled sessions are visible
      );

      if (data != null) {

        // Debug: print scheduled data
        debugPrint('[Calendar] Loaded data. Scheduled dates: ${data.scheduled.keys.toList()}');
        debugPrint('[Calendar] History dates: ${data.history.keys.toList()}');

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
    final maxMonth = DateTime(now.year, now.month + 2, 1); // Allow 2 months forward

    if (_currentMonth.isBefore(maxMonth)) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 380;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, colorScheme, isMobile, isSmallMobile),

          // Content
          if (_isLoading)
            _buildLoadingState(colorScheme)
          else if (_error != null)
            _buildErrorState(colorScheme)
          else if (_calendarData != null)
            _buildCalendarContent(context, colorScheme, isMobile, isSmallMobile),

          // Legend
          if (_calendarData != null && !_isLoading)
            _buildLegend(context, colorScheme, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile) {
    final monthName = _getMonthName(_currentMonth.month);
    final scheduledCount = _getScheduledCountForMonth();

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: colorScheme.primary,
                  size: isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Calendar',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (_calendarData != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_calendarData!.stats.totalDaysStudied} days studied',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colorScheme.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_calendarData!.stats.totalFlashcardsYear} cards this year',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (_calendarData!.stats.hasStudiedToday)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'You learned something new today!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 8),

          // Month navigation - full width on mobile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
                iconSize: 24,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  minimumSize: Size(isMobile ? 40 : 36, isMobile ? 40 : 36),
                ),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isSmallMobile
                          ? '${monthName.substring(0, 3)} ${_currentMonth.year}'
                          : '$monthName ${_currentMonth.year}',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (scheduledCount > 0)
                      Text(
                        '$scheduledCount reviews scheduled',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
                iconSize: 24,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  minimumSize: Size(isMobile ? 40 : 36, isMobile ? 40 : 36),
                ),
                tooltip: 'Next month',
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Error loading data',
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {
              _loadCalendarData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarContent(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    final today = DateTime.now();

    // Calculate cell size based on screen width - truly mobile first
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (isMobile ? 32 : 64); // Account for padding
    final cellSize = (availableWidth / 7).clamp(32.0, 44.0);
    final cellSpacing = isSmallMobile ? 2.0 : 4.0;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: (isSmallMobile
                ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                .map((day) => SizedBox(
                      width: cellSize,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallMobile ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: cellSpacing * 2),

          // Calendar grid
          ..._buildCalendarRows(
            context,
            colorScheme,
            firstWeekday,
            daysInMonth,
            today,
            cellSize,
            cellSpacing,
            isSmallMobile,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows(
    BuildContext context,
    ColorScheme colorScheme,
    int firstWeekday,
    int daysInMonth,
    DateTime today,
    double cellSize,
    double cellSpacing,
    bool isSmallMobile,
  ) {
    final rows = <Widget>[];
    var currentDay = 1;
    var currentWeekday = 1;

    // Calculate number of weeks
    final totalCells = (firstWeekday - 1) + daysInMonth;
    final numWeeks = (totalCells / 7).ceil();

    for (var week = 0; week < numWeeks; week++) {
      final cells = <Widget>[];

      for (var day = 0; day < 7; day++) {
        if (week == 0 && currentWeekday < firstWeekday) {
          // Empty cells before first day
          cells.add(SizedBox(width: cellSize, height: cellSize));
          currentWeekday++;
        } else if (currentDay <= daysInMonth) {
          final date = DateTime(_currentMonth.year, _currentMonth.month, currentDay);
          final dateString = _formatDateString(date);

          final historyDay = _calendarData?.history[dateString];
          final scheduledDay = _calendarData?.scheduled[dateString];

          final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
          final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
          final isFuture = date.isAfter(today);

          cells.add(
            _buildDayCell(
              context,
              colorScheme,
              currentDay,
              historyDay,
              scheduledDay,
              isToday,
              isPast,
              isFuture,
              cellSize,
              dateString,
              isSmallMobile,
            ),
          );
          currentDay++;
        } else {
          // Empty cells after last day
          cells.add(SizedBox(width: cellSize, height: cellSize));
        }
      }

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: cellSpacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: cells,
          ),
        ),
      );
    }

    return rows;
  }

  Widget _buildDayCell(
    BuildContext context,
    ColorScheme colorScheme,
    int day,
    CalendarDay? historyDay,
    CalendarDay? scheduledDay,
    bool isToday,
    bool isPast,
    bool isFuture,
    double cellSize,
    String dateString,
    bool isSmallMobile,
  ) {
    Color backgroundColor;
    Color textColor;
    bool hasActivity = false;
    bool hasScheduled = false;

    if (isPast || isToday) {
      // History cells - intensity based on count
      if (historyDay != null && historyDay.count > 0) {
        hasActivity = true;
        final intensity = _getIntensityLevel(historyDay.count);
        backgroundColor = _getGreenColor(intensity, colorScheme);
        // HIGH CONTRAST: Always dark text on light green, white on dark green
        textColor = intensity >= 3 ? Colors.white : const Color(0xFF1B4332);
      } else if (isToday && scheduledDay != null && scheduledDay.count > 0) {
        // Today with scheduled items but no history yet
        hasScheduled = true;
        final intensity = _getIntensityLevel(scheduledDay.count);
        backgroundColor = _getBlueColor(intensity, colorScheme);
        textColor = intensity >= 3 ? Colors.white : const Color(0xFF0D47A1);
      } else {
        backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        textColor = colorScheme.onSurfaceVariant;
      }
    } else {
      // Future cells - scheduled sessions
      if (scheduledDay != null && scheduledDay.count > 0) {
        hasScheduled = true;
        // Use blue shades based on count intensity
        final intensity = _getIntensityLevel(scheduledDay.count);
        backgroundColor = _getBlueColor(intensity, colorScheme);
        textColor = intensity >= 3 ? Colors.white : const Color(0xFF0D47A1);
      } else {
        backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        textColor = colorScheme.onSurfaceVariant;
      }
    }

    return GestureDetector(
      onTap: () => _showDayDetails(context, dateString, historyDay, scheduledDay, isPast, isFuture, isToday),
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(isSmallMobile ? 4 : 6),
          border: isToday
              ? Border.all(color: colorScheme.primary, width: 2.5)
              : (hasScheduled
                  ? Border.all(color: const Color(0xFF1671F4).withValues(alpha: 0.3), width: 1)
                  : null),
          boxShadow: (hasActivity || hasScheduled) ? [
            BoxShadow(
              color: (hasActivity ? const Color(0xFF40916C) : const Color(0xFF1671F4)).withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: isSmallMobile ? 11 : 12,
                fontWeight: isToday || hasActivity || hasScheduled ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            // Small indicator dot for scheduled sessions
            if (hasScheduled)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getIntensityLevel(int count) {
    final maxCount = _calendarData?.stats.maxCount ?? 1;
    if (maxCount == 0) return 0;

    final ratio = count / maxCount;
    if (ratio <= 0) return 0;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  // Improved green color palette with better contrast
  Color _getGreenColor(int level, ColorScheme colorScheme) {
    switch (level) {
      case 0:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      case 1:
        // Lighter green - good contrast with dark text
        return const Color(0xFFB7E4C7);
      case 2:
        // Medium green
        return const Color(0xFF74C69D);
      case 3:
        // Darker green - switch to white text
        return const Color(0xFF40916C);
      case 4:
        // Darkest green
        return const Color(0xFF1B4332);
      default:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }
  }

  // Improved blue color palette for scheduled sessions
  Color _getBlueColor(int level, ColorScheme colorScheme) {
    switch (level) {
      case 0:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      case 1:
        return const Color(0xFFD0E1FD); // Lightest blue
      case 2:
        return const Color(0xFF92BBFA); // Light blue
      case 3:
        return const Color(0xFF5496F7); // Medium blue
      case 4:
        return const Color(0xFF1671F4); // Darkest blue
      default:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }
  }

  void _showDayDetails(
    BuildContext context,
    String dateString,
    CalendarDay? historyDay,
    CalendarDay? scheduledDay,
    bool isPast,
    bool isFuture,
    bool isToday,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: isMobile ? 0.5 : 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Date header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPast
                          ? const Color(0xFF40916C).withValues(alpha: 0.1)
                          : colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPast ? Icons.history : (isToday ? Icons.today : Icons.event),
                      color: isPast ? const Color(0xFF40916C) : colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Content - show both history AND scheduled for today
              if ((isPast || isToday) && historyDay != null && historyDay.count > 0) ...[
                _buildDetailSection(
                  context,
                  'Flashcards studied',
                  '${historyDay.count}',
                  Icons.style,
                  const Color(0xFF40916C),
                ),
                const SizedBox(height: 16),
                Text(
                  'By deck:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...historyDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, false)),

                // Also show scheduled for today if available
                if (isToday && scheduledDay != null && scheduledDay.count > 0) ...[
                  const SizedBox(height: 20),
                  _buildDetailSection(
                    context,
                    'Still scheduled today',
                    '${scheduledDay.count}',
                    Icons.schedule,
                    colorScheme.primary,
                  ),
                  if (scheduledDay.decks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Decks to review:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...scheduledDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, true)),
                  ],
                ],
              ] else if ((isFuture || isToday) && scheduledDay != null && scheduledDay.count > 0) ...[
                _buildDetailSection(
                  context,
                  'Scheduled reviews',
                  '${scheduledDay.count}',
                  Icons.schedule,
                  colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'By deck:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...scheduledDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, true)),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPast
                              ? 'No activity this day'
                              : 'No scheduled reviews',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckRow(BuildContext context, DeckCount deck, ColorScheme colorScheme, bool isScheduled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isScheduled ? const Color(0xFF1671F4) : const Color(0xFF40916C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              deck.name,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isScheduled
                  ? const Color(0xFF1671F4).withValues(alpha: 0.1)
                  : const Color(0xFF40916C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${deck.count} cards',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isScheduled
                    ? const Color(0xFF1671F4)
                    : const Color(0xFF40916C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, ColorScheme colorScheme, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 12),
      child: Column(
        children: [
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 8),

          // Mobile: stack legend items vertically for better readability
          if (isMobile)
            Column(
              children: [
                // History legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Studied:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Less',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...List.generate(5, (index) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _getGreenColor(index, colorScheme),
                        borderRadius: BorderRadius.circular(3),
                        border: index == 0
                            ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5))
                            : null,
                      ),
                    )),
                    const SizedBox(width: 4),
                    Text(
                      'More',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Scheduled legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5496F7),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF1671F4).withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Scheduled reviews',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Desktop: horizontal layout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Less',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) => Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _getGreenColor(index, colorScheme),
                    borderRadius: BorderRadius.circular(3),
                    border: index == 0
                        ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5))
                        : null,
                  ),
                )),
                const SizedBox(width: 8),
                Text(
                  'More',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5496F7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Scheduled',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final monthName = _getMonthName(date.month);
      return '$monthName ${date.day}, ${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}

