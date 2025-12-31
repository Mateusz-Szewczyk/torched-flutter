import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/exams_provider.dart';
import '../services/exam_service.dart';

/// Widget for studying/taking an exam
class StudyExamWidget extends StatefulWidget {
  final Exam exam;
  final VoidCallback onExit;
  final ExamsProvider provider;

  const StudyExamWidget({
    super.key,
    required this.exam,
    required this.onExit,
    required this.provider,
  });

  @override
  State<StudyExamWidget> createState() => _StudyExamWidgetState();
}

class _StudyExamWidgetState extends State<StudyExamWidget> {
  // Exam state
  int _numQuestions = 10;
  bool _isSelectionStep = true;
  List<ExamQuestion> _selectedQuestions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  Map<int, int?> _userAnswers = {}; // questionIndex -> answerId
  bool _isExamCompleted = false;
  bool _isSubmitting = false;
  bool _resultSubmitted = false;
  String? _submitError;
  DateTime? _startTime;
  Timer? _timer;
  String _elapsedTime = '00:00';

  // UI Constants
  static const double _kMaxContentWidth = 750.0;

  @override
  void initState() {
    super.initState();
    // Guard: if no questions, ensure numQuestions stays valid
    final total = widget.exam.questions.length;
    _numQuestions = total > 0 ? min(total, 10) : 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && mounted) {
        final diff = DateTime.now().difference(_startTime!);
        final minutes = diff.inMinutes;
        final seconds = diff.inSeconds % 60;
        setState(() {
          _elapsedTime =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  List<ExamQuestion> _selectRandomQuestions(List<ExamQuestion> all, int count) {
    final shuffled = List<ExamQuestion>.from(all)..shuffle(Random());
    return shuffled.take(count).toList();
  }

  void _startExam() {
    final questions =
        _selectRandomQuestions(widget.exam.questions, _numQuestions);
    setState(() {
      _selectedQuestions = questions;
      _userAnswers = {};
      _score = 0;
      _currentQuestionIndex = 0;
      _isSelectionStep = false;
      _resultSubmitted = false;
      _submitError = null;
    });
    _startTimer();
  }

  void _handleAnswerSelect(int answerId) {
    final currentQuestion = _selectedQuestions[_currentQuestionIndex];

    // Check if already answered
    if (_userAnswers.containsKey(_currentQuestionIndex)) return;

    setState(() {
      _userAnswers[_currentQuestionIndex] = answerId;

      // Check if correct
      final selectedAnswer =
          currentQuestion.answers.firstWhere((a) => a.id == answerId);
      if (selectedAnswer.isCorrect) {
        _score++;
      }
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _selectedQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishExam();
    }
  }

  void _goToPreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _finishExam() {
    _timer?.cancel();
    setState(() {
      _isExamCompleted = true;
    });
    _submitResults();
  }

  Future<void> _submitResults() async {
    if (_resultSubmitted || _isSubmitting) return;

    final answeredQuestions =
        _userAnswers.entries.where((e) => e.value != null).toList();

    if (answeredQuestions.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final answers = answeredQuestions.map((entry) {
        return ExamResultAnswer(
          questionId: _selectedQuestions[entry.key].id ?? 0,
          selectedAnswerId: entry.value!,
          answerTime: DateTime.now().toIso8601String(),
        );
      }).toList();

      await widget.provider.submitExamResult(answers);

      if (mounted) {
        setState(() {
          _resultSubmitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _restartExam() {
    _timer?.cancel();
    setState(() {
      _isSelectionStep = true;
      _selectedQuestions = [];
      _currentQuestionIndex = 0;
      _score = 0;
      _userAnswers = {};
      _isExamCompleted = false;
      _resultSubmitted = false;
      _submitError = null;
      _startTime = null;
      _elapsedTime = '00:00';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > _kMaxContentWidth;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          // Allows scrolling on small screens, but centers content on large ones
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              margin: const EdgeInsets.symmetric(vertical: 24),
              // On desktop, add a subtle border/shadow to separate from background
              decoration: isDesktop
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : null,
              clipBehavior: isDesktop ? Clip.antiAlias : Clip.none,
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isSelectionStep) {
      return _buildSelectionStep(context);
    }

    if (_isExamCompleted) {
      return _buildResultsStep(context);
    }

    return _buildExamStep(context);
  }

  Widget _buildSelectionStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalQuestions = widget.exam.questions.length;

    if (totalQuestions == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min, // Shrink to fit
        children: [
          _buildAppBar(context, title: widget.exam.name),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined,
                    size: 64, color: colorScheme.surfaceContainerHighest),
                const SizedBox(height: 24),
                Text(
                  l10n?.examHasNoQuestions ?? 'This exam has no questions.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n?.backToExams ?? 'Back to Exams'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final maxQuestions = min(totalQuestions, 50);

    if (_numQuestions < 1 || _numQuestions > maxQuestions) {
      _numQuestions = maxQuestions.clamp(1, maxQuestions);
    }

    final sliderDivisions = max(1, maxQuestions - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppBar(context, title: widget.exam.name),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.selectNumberOfQuestions ?? 'Select Number of Questions',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      context,
                      '$_numQuestions',
                      l10n?.questions ?? 'Questions',
                      Icons.question_answer_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      context,
                      '~${(_numQuestions * 0.7).ceil()}m',
                      l10n?.estimatedTime ?? 'Est. Time',
                      Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Slider Control
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: colorScheme.outlineVariant, width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1', style: theme.textTheme.bodyMedium),
                        Text(
                          '$_numQuestions',
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary),
                        ),
                        Text('$maxQuestions',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 12),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 24),
                      ),
                      child: Slider(
                        value: _numQuestions.toDouble(),
                        min: 1,
                        max: maxQuestions.toDouble(),
                        divisions: sliderDivisions,
                        label: _numQuestions.toString(),
                        onChanged: (value) {
                          setState(() {
                            _numQuestions = value.round();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              FilledButton.icon(
                onPressed: _startExam,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n?.startExam ?? 'Start Exam'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      BuildContext context, String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = _selectedQuestions.length;
    final currentQuestion =
        total > 0 ? _selectedQuestions[_currentQuestionIndex] : null;
    final selectedAnswerId = _userAnswers[_currentQuestionIndex];
    final isAnswered = selectedAnswerId != null;

    final progress = total > 0 ? (_currentQuestionIndex + 1) / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min, // Important for centering
      children: [
        _buildExamAppBar(context, total, progress),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentQuestion!.text,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),
                ...currentQuestion.answers.asMap().entries.map((entry) {
                  return _buildAnswerOption(
                    entry.key,
                    entry.value,
                    selectedAnswerId,
                    isAnswered,
                    colorScheme,
                  );
                }),
              ],
            ),
          ),
        _buildBottomBar(context, l10n, isAnswered, total, colorScheme),
      ],
    );
  }

  Widget _buildAnswerOption(int index, ExamAnswer answer, int? selectedAnswerId,
      bool isAnswered, ColorScheme colorScheme) {
    final isSelected = selectedAnswerId == answer.id;
    final isCorrect = answer.isCorrect;
    final showResult = isAnswered;

    Color backgroundColor = colorScheme.surface;
    Color borderColor = colorScheme.outlineVariant;
    Color textColor = colorScheme.onSurface;
    IconData? statusIcon;
    Color? statusColor;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade900;
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade900;
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
      } else {
        // Not selected, not correct (neutral)
        backgroundColor = colorScheme.surface.withOpacity(0.5);
      }
    } else if (isSelected) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      textColor = colorScheme.onPrimaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isAnswered ? null : () => _handleAnswerSelect(answer.id ?? 0),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: isSelected || (showResult && isCorrect) ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    answer.text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (showResult && statusIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(statusIcon, color: statusColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalQuestions = _selectedQuestions.length;
    final scorePercentage =
        totalQuestions > 0 ? (_score / totalQuestions * 100).round() : 0;
    final isPassing = scorePercentage >= 70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppBar(context, title: l10n?.examComplete ?? 'Exam Complete'),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isPassing
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassing ? Icons.emoji_events_rounded : Icons.school_rounded,
                  size: 64,
                  color: isPassing ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPassing
                    ? l10n?.congratulationsPassed ?? 'Passed!'
                    : l10n?.keepPracticing ?? 'Keep Learning!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $scorePercentage%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Main Score Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultStat(
                      context,
                      '$_score',
                      l10n?.correct ?? 'Correct',
                      Colors.green,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: colorScheme.outlineVariant,
                    ),
                    _buildResultStat(
                      context,
                      '${totalQuestions - _score}',
                      l10n?.incorrect ?? 'Wrong',
                      Colors.red,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: colorScheme.outlineVariant,
                    ),
                    _buildResultStat(
                      context,
                      _elapsedTime,
                      l10n?.time ?? 'Time',
                      colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (_isSubmitting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_resultSubmitted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(l10n?.resultsSaved ?? 'Results saved',
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (_submitError != null)
                Text(_submitError!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _restartExam,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(l10n?.tryAgain ?? 'Try Again'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onExit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(l10n?.backToExams ?? 'Exit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat(
      BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  // --- Common UI Components ---

  Widget _buildAppBar(BuildContext context, {required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildExamAppBar(BuildContext context, int total, double progress) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.exam.name,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis),
                      Text('${_currentQuestionIndex + 1} of $total',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(_elapsedTime,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onExit,
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations? l10n,
      bool isAnswered, int total, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            OutlinedButton.icon(
              onPressed: _goToPreviousQuestion,
              icon: const Icon(Icons.chevron_left),
              label: Text(l10n?.previous ?? 'Prev'),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: isAnswered ? _goToNextQuestion : null,
            icon: Icon(_currentQuestionIndex < total - 1
                ? Icons.chevron_right
                : Icons.check),
            label: Text(_currentQuestionIndex < total - 1
                ? l10n?.next ?? 'Next'
                : l10n?.finish ?? 'Finish'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}