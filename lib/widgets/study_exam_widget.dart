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

  List<ExamQuestion> _selectRandomQuestions(
      List<ExamQuestion> all, int count) {
    final shuffled = List<ExamQuestion>.from(all)..shuffle(Random());
    return shuffled.take(count).toList();
  }

  void _startExam() {
    final questions = _selectRandomQuestions(widget.exam.questions, _numQuestions);
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

    final answeredQuestions = _userAnswers.entries
        .where((e) => e.value != null)
        .toList();

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

    // If exam has no questions, show a friendly message instead of slider
    if (totalQuestions == 0) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.exam.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onExit,
              tooltip: 'Exit',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: 48, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n?.examHasNoQuestions ?? 'This exam has no questions.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n?.backToExams ?? 'Back to Exams'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final maxQuestions = min(totalQuestions, 50);

    // Ensure current _numQuestions is within bounds
    if (_numQuestions < 1 || _numQuestions > maxQuestions) {
      _numQuestions = maxQuestions.clamp(1, maxQuestions);
    }

    // Safe divisions value for Slider (must be >= 1)
    final sliderDivisions = max(1, maxQuestions - 1);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.exam.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
            tooltip: 'Exit',
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  l10n?.selectNumberOfQuestions ?? 'Select Number of Questions',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Slider
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: TextEditingController(
                            text: _numQuestions.toString()),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final numVal = int.tryParse(value);
                          if (numVal != null) {
                            final clamped = numVal.clamp(1, maxQuestions);
                            setState(() {
                              _numQuestions = clamped;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$_numQuestions',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            l10n?.questions ?? 'Questions',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '~${(_numQuestions * 0.7).ceil()}m',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            l10n?.estimatedTime ?? 'Est. Time',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Start button
                FilledButton.icon(
                  onPressed: _startExam,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n?.startExam ?? 'Start Exam'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = _selectedQuestions.length;
    final currentQuestion = total > 0 ? _selectedQuestions[_currentQuestionIndex] : null;
    final selectedAnswerId = _userAnswers[_currentQuestionIndex];
    final isAnswered = selectedAnswerId != null;

    // Safe progress (avoid division by zero)
    final progress = total > 0 ? (_currentQuestionIndex + 1) / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.exam.name, overflow: TextOverflow.ellipsis),
        actions: [
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _elapsedTime,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Progress
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                total > 0 ? '${_currentQuestionIndex + 1}/$total' : '0/0',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          // Close button (moved to right)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
            tooltip: 'Exit Exam',
          ),
        ],
      ),
      body: total == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz_outlined,
                        size: 48, color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.examHasNoQuestions ?? 'This exam has no questions.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n?.backToExams ?? 'Back to Exams'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),

                // Question
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question text
                        Text(
                          currentQuestion!.text,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Answer options
                        ...currentQuestion.answers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final answer = entry.value;
                          final isSelected = selectedAnswerId == answer.id;
                          final showResult = isAnswered;
                          final isCorrect = answer.isCorrect;

                          Color? backgroundColor;
                          Color? borderColor;
                          Color? textColor;

                          if (showResult) {
                            if (isCorrect) {
                              backgroundColor = Colors.green.withOpacity(0.1);
                              borderColor = Colors.green;
                              textColor = Colors.green.shade700;
                            } else if (isSelected && !isCorrect) {
                              backgroundColor = Colors.red.withOpacity(0.1);
                              borderColor = Colors.red;
                              textColor = Colors.red.shade700;
                            }
                          } else if (isSelected) {
                            backgroundColor = colorScheme.primaryContainer;
                            borderColor = colorScheme.primary;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: backgroundColor ?? colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: isAnswered
                                    ? null
                                    : () => _handleAnswerSelect(answer.id ?? 0),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: borderColor ??
                                          colorScheme.outlineVariant,
                                      width:
                                          isSelected || (showResult && isCorrect)
                                              ? 2
                                              : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      // Letter indicator
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme
                                                  .surfaceContainerHighest,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            String.fromCharCode(65 + index),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? colorScheme.onPrimary
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Answer text
                                      Expanded(
                                        child: Text(
                                          answer.text,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : null,
                                          ),
                                        ),
                                      ),
                                      // Result icon
                                      if (showResult)
                                        Icon(
                                          isCorrect
                                              ? Icons.check_circle
                                              : (isSelected
                                                  ? Icons.cancel
                                                  : null),
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Navigation buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Previous button
                      if (_currentQuestionIndex > 0)
                        OutlinedButton.icon(
                          onPressed: _goToPreviousQuestion,
                          icon: const Icon(Icons.chevron_left),
                          label: Text(l10n?.previous ?? 'Previous'),
                        )
                      else
                        const SizedBox.shrink(),

                      const Spacer(),

                      // Next/Finish button
                      FilledButton.icon(
                        onPressed: isAnswered ? _goToNextQuestion : null,
                        icon: Icon(
                          _currentQuestionIndex < total - 1
                              ? Icons.chevron_right
                              : Icons.check,
                        ),
                        label: Text(
                          _currentQuestionIndex < total - 1
                              ? l10n?.next ?? 'Next'
                              : l10n?.finish ?? 'Finish',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResultsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalQuestions = _selectedQuestions.length;
    final scorePercentage = totalQuestions > 0
        ? (_score / totalQuestions * 100).round()
        : 0;
    final isPassing = scorePercentage >= 70;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.exam.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
            tooltip: 'Exit',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPassing
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassing ? Icons.emoji_events : Icons.school,
                  size: 50,
                  color: isPassing ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n?.examComplete ?? 'Exam Complete!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                isPassing
                    ? l10n?.congratulationsPassed ?? 'Congratulations! You passed!'
                    : l10n?.keepPracticing ?? 'Keep practicing!',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_score/$totalQuestions',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$scorePercentage% ${l10n?.correct ?? 'Correct'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    value: '$_score',
                    label: l10n?.correctAnswers ?? 'Correct',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                  _buildStatCard(
                    icon: Icons.cancel,
                    iconColor: Colors.red,
                    value: '${totalQuestions - _score}',
                    label: l10n?.incorrectAnswers ?? 'Incorrect',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                  _buildStatCard(
                    icon: Icons.access_time,
                    iconColor: colorScheme.primary,
                    value: _elapsedTime,
                    label: l10n?.timeTaken ?? 'Time',
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit status
              if (_isSubmitting)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n?.submittingResults ?? 'Submitting results...'),
                    ],
                  ),
                ),

              if (_resultSubmitted)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Text(l10n?.resultsSaved ?? 'Results saved!'),
                    ],
                  ),
                ),

              if (_submitError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _submitError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _restartExam,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n?.tryAgain ?? 'Try Again'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n?.backToExams ?? 'Back to Exams'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

