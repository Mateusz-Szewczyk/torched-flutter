import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/flashcards_provider.dart';

/// Rating for flashcard answer
class FlashcardRating {
  final int flashcardId;
  final int rating;
  final String answeredAt;

  FlashcardRating({
    required this.flashcardId,
    required this.rating,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
    'flashcard_id': flashcardId,
    'rating': rating,
    'answered_at': answeredAt,
  };
}

/// Study deck widget - Mobile-first flashcard study experience
/// Redesigned for focus, clarity, and ease of use.
class StudyDeckWidget extends StatefulWidget {
  final Deck deck;
  final int? studySessionId;
  final List<Flashcard> availableCards;
  final String? nextSessionDate;
  final int? conversationId;
  final VoidCallback onExit;
  final FlashcardsProvider provider;

  const StudyDeckWidget({
    super.key,
    required this.deck,
    this.studySessionId,
    required this.availableCards,
    this.nextSessionDate,
    this.conversationId,
    required this.onExit,
    required this.provider,
  });

  @override
  State<StudyDeckWidget> createState() => _StudyDeckWidgetState();
}

class _StudyDeckWidgetState extends State<StudyDeckWidget>
    with TickerProviderStateMixin {
  late List<Flashcard> _cardsQueue;
  late int _initialTotalCards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isSubmitting = false;
  String? _submitError;
  List<FlashcardRating> _localRatings = [];
  Map<int, int> _cardSeenCount = {};

  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _swipeController;
  late AnimationController _celebrationController;

  // Swipe tracking
  double _dragX = 0;
  double _dragY = 0;

  // Stats tracking
  int _easyCount = 0;
  int _goodCount = 0;
  int _hardCount = 0;

  @override
  void initState() {
    super.initState();
    _cardsQueue = _shuffle(List.from(widget.availableCards));
    _initialTotalCards = _cardsQueue.length;

    for (var card in widget.availableCards) {
      _cardSeenCount[card.id ?? 0] = 0;
    }

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _swipeController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  List<Flashcard> _shuffle(List<Flashcard> cards) {
    final random = Random();
    for (int i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
    return cards;
  }

  void _handleFlip() {
    if (_isSubmitting) return;
    HapticFeedback.selectionClick();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _onPanStart(DragStartDetails details) {
    _swipeController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = 120.0;
    if (_dragX.abs() > threshold) {
      if (_dragX > 0) {
        _animateSwipeOut(1, () => _handleRating(5)); // Easy (Right)
      } else {
        _animateSwipeOut(-1, () => _handleRating(0)); // Hard (Left)
      }
    } else {
      _resetSwipe();
    }
  }

  void _animateSwipeOut(int direction, VoidCallback onComplete) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = direction * screenWidth * 1.5;

    _swipeController.reset();
    final startX = _dragX;

    _swipeController.addListener(() {
      setState(() {
        _dragX = startX + (targetX - startX) * _swipeController.value;
      });
    });

    _swipeController.forward().then((_) {
      onComplete();
      _resetSwipe();
    });
  }

  void _resetSwipe() {
    setState(() {
      _dragX = 0;
      _dragY = 0;
    });
  }

  void _handleRating(int rating) {
    if (_cardsQueue.isEmpty) return;

    final currentCard = _cardsQueue[_currentIndex];

    if (rating == 0) _hardCount++;
    else if (rating == 3) _goodCount++;
    else if (rating == 5) _easyCount++;

    _localRatings.add(FlashcardRating(
      flashcardId: currentCard.id ?? 0,
      rating: rating,
      answeredAt: DateTime.now().toIso8601String(),
    ));

    final updatedQueue = List<Flashcard>.from(_cardsQueue);
    if (rating == 0 || rating == 3) {
      final removed = updatedQueue.removeAt(_currentIndex);
      updatedQueue.add(removed);
    } else {
      updatedQueue.removeAt(_currentIndex);
    }

    if (updatedQueue.isEmpty) {
      _celebrationController.forward();
      setState(() {
        _cardsQueue = [];
        _currentIndex = 0;
      });
      return;
    }

    int nextIndex = _currentIndex;
    if (nextIndex >= updatedQueue.length) nextIndex = 0;

    setState(() {
      _cardsQueue = updatedQueue;
      _currentIndex = nextIndex;
      _isFlipped = false;
    });
    _flipController.reset();
    HapticFeedback.lightImpact();
  }

  Future<void> _handleFinish() async {
    setState(() => _isSubmitting = true);
    try {
      final ratingsJson = _localRatings.map((r) => r.toJson()).toList();
      await widget.provider.submitRatings(ratingsJson);
      widget.onExit();
    } catch (e) {
      setState(() => _submitError = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showStatsBottomSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Progress', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'Easy', count: _easyCount, color: Colors.green),
                _StatChip(label: 'Good', count: _goodCount, color: Colors.orange),
                _StatChip(label: 'Hard', count: _hardCount, color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_cardsQueue.isEmpty) {
      return _buildSessionComplete(context, l10n, cs, isMobile);
    }

    final currentCard = _cardsQueue[_currentIndex];
    final progress = _initialTotalCards > 0
        ? ((_initialTotalCards - _cardsQueue.length) / _initialTotalCards)
        : 0.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _MinimalStudyAppBar(
              deckName: widget.deck.name,
              progress: progress,
              currentIndex: _initialTotalCards - _cardsQueue.length,
              total: _initialTotalCards,
              onClose: widget.onExit,
              onShowStats: _showStatsBottomSheet,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: GestureDetector(
                    onTap: _handleFlip,
                    onPanStart: _isFlipped ? _onPanStart : null,
                    onPanUpdate: _isFlipped ? _onPanUpdate : null,
                    onPanEnd: _isFlipped ? _onPanEnd : null,
                    child: Transform.translate(
                      offset: Offset(_dragX, _dragY),
                      child: Transform.rotate(
                        angle: _dragX * 0.0005,
                        child: _buildCleanFlipCard(currentCard, cs, theme, isMobile),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _BottomActionsBar(
              isFlipped: _isFlipped,
              onFlip: _handleFlip,
              onHard: () => _handleRating(0),
              onGood: () => _handleRating(3),
              onEasy: () => _handleRating(5),
              l10n: l10n,
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanFlipCard(Flashcard card, ColorScheme cs, ThemeData theme, bool isMobile) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * pi;
        final isFront = angle < pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: isMobile ? 320 : 400),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFront ? 'QUESTION' : 'ANSWER',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: isFront ? Matrix4.identity() : Matrix4.identity()..rotateY(pi),
                            child: Text(
                              isFront ? card.question : card.answer,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: cs.onSurface, fontWeight: FontWeight.w500, height: 1.4
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isFront)
                      Text('Tap to reveal', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                    else
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: Text('Rate your answer', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionComplete(BuildContext context, AppLocalizations? l10n, ColorScheme cs, bool isMobile) {
    final total = _easyCount + _goodCount + _hardCount;
    final accuracy = total > 0 ? ((_easyCount + _goodCount) / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: cs.primary),
              const SizedBox(height: 24),
              Text('Session Complete!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('You reviewed $_initialTotalCards cards with $accuracy% accuracy.', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(label: 'Easy', count: _easyCount, color: Colors.green),
                  _StatChip(label: 'Good', count: _goodCount, color: Colors.orange),
                  _StatChip(label: 'Hard', count: _hardCount, color: Colors.red),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleFinish,
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Save & Exit'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: widget.onExit, child: const Text('Discard Session')),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalStudyAppBar extends StatelessWidget {
  final String deckName;
  final double progress;
  final int currentIndex;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onShowStats;

  const _MinimalStudyAppBar({
    required this.deckName,
    required this.progress,
    required this.currentIndex,
    required this.total,
    required this.onClose,
    required this.onShowStats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deckName, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$currentIndex / $total cards', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(onPressed: onShowStats, icon: const Icon(Icons.bar_chart_rounded)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: cs.surfaceContainerHighest),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionsBar extends StatelessWidget {
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback onHard;
  final VoidCallback onGood;
  final VoidCallback onEasy;
  final AppLocalizations? l10n;
  final ColorScheme cs;

  const _BottomActionsBar({
    required this.isFlipped,
    required this.onFlip,
    required this.onHard,
    required this.onGood,
    required this.onEasy,
    this.l10n,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.3))),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isFlipped
            ? Row(
                key: const ValueKey('rating'),
                children: [
                  Expanded(child: _RatingChipButton(label: 'Hard', color: Colors.red, onTap: onHard)),
                  const SizedBox(width: 12),
                  Expanded(child: _RatingChipButton(label: 'Good', color: Colors.orange, onTap: onGood)),
                  const SizedBox(width: 12),
                  Expanded(child: _RatingChipButton(label: 'Easy', color: Colors.green, onTap: onEasy)),
                ],
              )
            : SizedBox(
                key: const ValueKey('flip'),
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onFlip,
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Show Answer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
      ),
    );
  }
}

class _RatingChipButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingChipButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color.withOpacity(0.7))),
      ],
    );
  }
}
