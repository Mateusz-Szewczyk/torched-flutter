import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

/// Learning Calendar Widget - GitHub-style contribution graph
/// Shows study history and scheduled flashcard reviews
class LearningCalendarWidget extends StatefulWidget {
  /// If true, the calendar expands to fill available width
  final bool expandToFill;

  const LearningCalendarWidget({
    super.key,
    this.expandToFill = false,
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

  const _CalendarCell({
    this.dayNumber,
    required this.backgroundColor,
    required this.isToday,
    required this.cellSize,
    this.onTap,
    required this.colorScheme,
  });

  @override
  State<_CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<_CalendarCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Calculate text color based on background luminance
    final textColor = widget.backgroundColor.computeLuminance() > 0.5
        ? Colors.black54
        : Colors.white70;

    // Adjust font size based on cell size for readability
    final fontSize = widget.cellSize < 20 ? widget.cellSize * 0.5 : widget.cellSize * 0.38;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.cellSize,
          height: widget.cellSize,
          decoration: BoxDecoration(
            color: _isHovered
                ? Color.lerp(widget.backgroundColor, Colors.white, 0.15)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(2),
            border: widget.isToday
                ? Border.all(
                    color: widget.colorScheme.primary,
                    width: 1.5,
                  )
                : _isHovered
                    ? Border.all(
                        color: widget.colorScheme.onSurface.withAlpha(76),
                        width: 1,
                      )
                    : null,
          ),
          child: widget.dayNumber != null
              ? Center(
                  child: Text(
                    '${widget.dayNumber}',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 380;
    final isDesktop = screenWidth >= 900;

    // On desktop, constrain the calendar width to prevent it from stretching
    // Unless expandToFill is true, then let the parent control the size
    final double? maxCalendarWidth;
    if (widget.expandToFill) {
      maxCalendarWidth = null; // No constraint - fill available space
    } else {
      maxCalendarWidth = isDesktop ? 320.0 : (isMobile ? double.infinity : 400.0);
    }

    return Center(
      child: Container(
        constraints: maxCalendarWidth != null
            ? BoxConstraints(maxWidth: maxCalendarWidth)
            : null,
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 0 : (isDesktop ? 0 : 8),
          vertical: 8,
        ),
        // GitHub style: Cleaner container, less elevation
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: widget.expandToFill
              ? null // No border when embedded in a container
              : Border.all(
                  color: colorScheme.outlineVariant.withAlpha(102),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile) {
    final monthName = _getMonthName(_currentMonth.month);
    final scheduledCount = _getScheduledCountForMonth();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : (isDesktop ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDesktop ? 'Activity' : 'Contribution Activity',
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

          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavButton(Icons.chevron_left, _previousMonth, colorScheme),

              Column(
                children: [
                  Text(
                    isSmallMobile || isDesktop
                        ? '${monthName.substring(0, 3)} ${_currentMonth.year}'
                        : '$monthName ${_currentMonth.year}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (scheduledCount > 0)
                    Text(
                      '$scheduledCount scheduled',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blueAccent, // Flat blue for text
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),

              _buildNavButton(Icons.chevron_right, _nextMonth, colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
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
      child: Text('Error loading data', style: TextStyle(color: colorScheme.error)),
    );
  }

  Widget _buildCalendarContent(BuildContext context, ColorScheme colorScheme, bool isMobile, bool isSmallMobile) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    final today = DateTime.now();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    // GitHub style: cell spacing
    const double cellSpacing = 3.0;

    // Day labels - shorter on desktop for compact look
    final dayLabels = isDesktop
        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : isSmallMobile
            ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
            : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    // Use LayoutBuilder to get available width when expandToFill is enabled
    if (widget.expandToFill) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate cell size based on available width
          final availableWidth = constraints.maxWidth - 32; // padding
          final calculatedCellSize = (availableWidth - (cellSpacing * 6)) / 7;
          // Clamp cell size to reasonable bounds
          final cellSize = calculatedCellSize.clamp(16.0, 50.0);
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

    // Default fixed cell sizes when not expanding
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
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
        constraints: widget.expandToFill
            ? null
            : BoxConstraints(maxWidth: totalGridWidth + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weekday headers - tightly packed
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
                        color: colorScheme.onSurfaceVariant.withAlpha(179),
                        letterSpacing: -0.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: cellSpacing + 2),

            // Calendar grid - centered and constrained
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
    DateTime today,
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

    // Empty cell color
    final emptyColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF161B22)
        : const Color(0xFFEBEDF0);

    for (var week = 0; week < numWeeks; week++) {
      final cells = <Widget>[];

      for (var day = 0; day < 7; day++) {
        final isLast = day == 6;

        if (week == 0 && currentWeekday < firstWeekday) {
          // Empty cell before month starts
          cells.add(
            Container(
              width: cellSize,
              height: cellSize,
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              decoration: BoxDecoration(
                color: emptyColor.withAlpha(76),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
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

          // Determine background color
          Color backgroundColor;
          if (isPast || isToday) {
            if (historyDay != null && historyDay.count > 0) {
              final intensity = _getIntensityLevel(historyDay.count);
              backgroundColor = _getGitHubGreenColor(intensity);
            } else if (isToday && scheduledDay != null && scheduledDay.count > 0) {
              backgroundColor = _getGitHubBlueColor(1);
            } else {
              backgroundColor = emptyColor;
            }
          } else {
            if (scheduledDay != null && scheduledDay.count > 0) {
              final intensity = _getIntensityLevel(scheduledDay.count);
              backgroundColor = _getGitHubBlueColor(intensity);
            } else {
              backgroundColor = emptyColor;
            }
          }

          final dayNum = currentDay;
          cells.add(
            Container(
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              child: _CalendarCell(
                dayNumber: dayNum,
                backgroundColor: backgroundColor,
                isToday: isToday,
                cellSize: cellSize,
                colorScheme: colorScheme,
                onTap: () => _showDayDetails(
                  context,
                  dateString,
                  historyDay,
                  scheduledDay,
                  isPast,
                  isFuture,
                  isToday,
                ),
              ),
            ),
          );
          currentDay++;
        } else {
          // Empty cell after month ends
          cells.add(
            Container(
              width: cellSize,
              height: cellSize,
              margin: EdgeInsets.only(right: isLast ? 0 : cellSpacing),
              decoration: BoxDecoration(
                color: emptyColor.withAlpha(76),
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
    final maxCount = _calendarData?.stats.maxCount ?? 1;
    if (maxCount == 0) return 0;
    final ratio = count / maxCount;
    if (ratio <= 0) return 0;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  // Official GitHub contribution graph colors
  Color _getGitHubGreenColor(int level) {
    switch (level) {
      case 0: return const Color(0xFFEBEDF0); // Empty (Light mode ref)
      case 1: return const Color(0xFF9BE9A8); // Lightest green
      case 2: return const Color(0xFF40C463); // Light green
      case 3: return const Color(0xFF30A14E); // Medium green
      case 4: return const Color(0xFF216E39); // Darkest green
      default: return const Color(0xFFEBEDF0);
    }
  }

  // Flat blue palette for scheduled items (matches flat style of green)
  Color _getGitHubBlueColor(int level) {
    switch (level) {
      case 0: return const Color(0xFFEBEDF0);
      case 1: return const Color(0xFFCAE8FF);
      case 2: return const Color(0xFF79C0FF);
      case 3: return const Color(0xFF1F6FEB);
      case 4: return const Color(0xFF0A3069);
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Spacer(),
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

          SizedBox(width: isDesktop ? 12 : 16),

          // Scheduled legend
          Container(
            width: cellSizeLegend,
            height: cellSizeLegend,
            decoration: BoxDecoration(
              color: const Color(0xFF1F6FEB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text('Scheduled', style: TextStyle(fontSize: fontSize, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ... (The rest of the helper methods: _showDayDetails, _buildDetailSection, etc. remain exactly the same as before to preserve logic) ...

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPast
                          ? const Color(0xFF216E39).withAlpha(26) // Github green
                          : Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPast ? Icons.history : (isToday ? Icons.today : Icons.event),
                      color: isPast ? const Color(0xFF216E39) : Colors.blue,
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
                            style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Detail Logic (Preserved)
              if ((isPast || isToday) && historyDay != null && historyDay.count > 0) ...[
                _buildDetailSection(context, 'Flashcards studied', '${historyDay.count}', Icons.style, const Color(0xFF216E39)),
                const SizedBox(height: 16),
                ...historyDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, false)),
              ] else if ((isFuture || isToday) && scheduledDay != null && scheduledDay.count > 0) ...[
                _buildDetailSection(context, 'Scheduled reviews', '${scheduledDay.count}', Icons.schedule, Colors.blue),
                const SizedBox(height: 16),
                ...scheduledDay.decks.map((deck) => _buildDeckRow(context, deck, colorScheme, true)),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No activity this day', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
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

  Widget _buildDeckRow(BuildContext context, DeckCount deck, ColorScheme colorScheme, bool isScheduled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isScheduled ? Colors.blue : const Color(0xFF216E39),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(deck.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('${deck.count} cards', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
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