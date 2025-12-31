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
/// Optimized for Desktop with centered navigation and actions
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
  bool _isLoadingHardCards = false;

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

  // UI Constants for Desktop constraints
  static const double _kMaxCardWidth = 600.0;
  static const double _kMaxHeaderWidth = 800.0;

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
    // Note: We still use full screen width for flight logic to ensure it leaves the view
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

    if (rating == 0)
      _hardCount++;
    else if (rating == 3)
      _goodCount++;
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

  Future<void> _handleSave() async {
    if (_localRatings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No progress to save yet'),
            duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ratingsJson = _localRatings.map((r) => r.toJson()).toList();
      await widget.provider.submitRatings(ratingsJson);
      _localRatings.clear(); // Clear after successful save
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved! ✓'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showStatsBottomSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      constraints: const BoxConstraints(maxWidth: 600), // constrain sheet too
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Progress',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    label: 'Easy', count: _easyCount, color: Colors.green),
                _StatChip(
                    label: 'Good', count: _goodCount, color: Colors.orange),
                _StatChip(
                    label: 'Hard', count: _hardCount, color: Colors.red),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        // Center vertically
        child: Center(
          // SingleChildScrollView prevents overflow on very short screens
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrink wrap the column height
              children: [
                // 1. Top Section (Centered Header)
                if (_cardsQueue.isNotEmpty)
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: _kMaxHeaderWidth),
                      child: _MinimalStudyAppBar(
                        deckName: widget.deck.name,
                        progress: _initialTotalCards > 0
                            ? ((_initialTotalCards - _cardsQueue.length) /
                                _initialTotalCards)
                            : 0.0,
                        currentIndex: _initialTotalCards - _cardsQueue.length,
                        total: _initialTotalCards,
                        onClose: widget.onExit,
                        onShowStats: _showStatsBottomSheet,
                        onSave: _handleSave,
                        isSaving: _isSubmitting,
                      ),
                    ),
                  ),

                // 2. Middle Section (Centered Card)
                // Removed Expanded so it doesn't push header/footer away
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: _kMaxCardWidth),
                    child: _cardsQueue.isEmpty
                        ? (_initialTotalCards == 0
                            ? _buildNoCardsAvailable(
                                context, l10n, cs, isMobile)
                            : _buildSessionComplete(
                                context, l10n, cs, isMobile))
                        : Padding(
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
                                    child: _buildCleanFlipCard(
                                        _cardsQueue[_currentIndex],
                                        cs,
                                        theme,
                                        isMobile),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                // 3. Bottom Section (Centered Actions)
                if (_cardsQueue.isNotEmpty)
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: _kMaxCardWidth),
                      child: _BottomActionsBar(
                        isFlipped: _isFlipped,
                        onFlip: _handleFlip,
                        onHard: () => _handleRating(0),
                        onGood: () => _handleRating(3),
                        onEasy: () => _handleRating(5),
                        l10n: l10n,
                        cs: cs,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanFlipCard(
      Flashcard card, ColorScheme cs, ThemeData theme, bool isMobile) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * pi;
        final isFront = angle < pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? _buildCardFace(
                  content: card.question,
                  label: 'QUESTION',
                  cs: cs,
                  theme: theme,
                  isMobile: isMobile,
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildCardFace(
                    content: card.answer,
                    label: 'ANSWER',
                    cs: cs,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCardFace({
    required String content,
    required String label,
    required ColorScheme cs,
    required ThemeData theme,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      // Adaptive height: taller on mobile to fill space, fixed reasonable height on desktop
      constraints: BoxConstraints(
          minHeight: isMobile ? 320 : 400,
          maxHeight: isMobile ? double.infinity : 600),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.4),
                    ),
                  ),
                ),
              ),
              Text(
                  label == 'QUESTION' ? 'Tap to reveal' : 'Rate your answer',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionComplete(BuildContext context, AppLocalizations? l10n,
      ColorScheme cs, bool isMobile) {
    final total = _easyCount + _goodCount + _hardCount;
    final accuracy =
        total > 0 ? ((_easyCount + _goodCount) / total * 100).round() : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: cs.primary),
            const SizedBox(height: 24),
            Text('Session Complete!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'You reviewed $_initialTotalCards cards with $accuracy% accuracy.',
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    label: 'Easy', count: _easyCount, color: Colors.green),
                _StatChip(
                    label: 'Good', count: _goodCount, color: Colors.orange),
                _StatChip(label: 'Hard', count: _hardCount, color: Colors.red),
              ],
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _handleFinish,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save & Exit'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
                onPressed: widget.onExit, child: const Text('Discard Session')),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCardsAvailable(BuildContext context, AppLocalizations? l10n,
      ColorScheme cs, bool isMobile) {
    String nextSessionText = 'N/A';
    if (widget.nextSessionDate != null) {
      try {
        final nextDate = DateTime.parse(widget.nextSessionDate!);
        final now = DateTime.now();
        final difference = nextDate.difference(now);

        if (difference.inDays > 0) {
          nextSessionText =
              'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
        } else if (difference.inHours > 0) {
          nextSessionText =
              'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
        } else if (difference.inMinutes > 0) {
          nextSessionText =
              'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
        } else {
          nextSessionText = 'now';
        }
      } catch (_) {
        nextSessionText = widget.nextSessionDate!;
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded,
                  size: 48, color: cs.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'All Caught Up! 🎉',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve completed all scheduled reviews for this deck.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Next review: $nextSessionText',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isLoadingHardCards ? null : _handleReviewHardCards,
                icon: _isLoadingHardCards
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary),
                      )
                    : const Icon(Icons.replay_rounded),
                label: Text(
                    _isLoadingHardCards ? 'Loading...' : 'Review Hard Cards'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: cs.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: widget.onExit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Decks'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReviewHardCards() async {
    setState(() => _isLoadingHardCards = true);

    try {
      final success = await widget.provider.retakeHardCards();

      if (success && mounted) {
        final newCards = widget.provider.availableCards;
        // ignore: unused_local_variable
        final newSessionId = widget.provider.studySessionId;

        if (newCards.isNotEmpty) {
          setState(() {
            _cardsQueue = _shuffle(List.from(newCards));
            _initialTotalCards = _cardsQueue.length;
            _currentIndex = 0;
            _isFlipped = false;
            _localRatings.clear();
            _easyCount = 0;
            _goodCount = 0;
            _hardCount = 0;
            _cardSeenCount.clear();
            for (var card in newCards) {
              _cardSeenCount[card.id ?? 0] = 0;
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hard cards found for review'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hard cards available to review'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hard cards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHardCards = false);
      }
    }
  }
}

class _MinimalStudyAppBar extends StatelessWidget {
  final String deckName;
  final double progress;
  final int currentIndex;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onShowStats;
  final VoidCallback onSave;
  final bool isSaving;

  const _MinimalStudyAppBar({
    required this.deckName,
    required this.progress,
    required this.currentIndex,
    required this.total,
    required this.onClose,
    required this.onShowStats,
    required this.onSave,
    this.isSaving = false,
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deckName,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('$currentIndex / $total cards',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onShowStats,
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'View Stats',
              ),
              IconButton(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary),
                      )
                    : const Icon(Icons.save_outlined),
                tooltip: 'Save Progress',
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Exit',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest),
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
        // Removed border for cleaner centered look
        // border: Border(
        //     top: BorderSide(color: cs.outlineVariant.withOpacity(0.3))),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isFlipped
            ? Row(
                key: const ValueKey('rating'),
                children: [
                  Expanded(
                      child: _RatingChipButton(
                          label: 'Hard', color: Colors.red, onTap: onHard)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _RatingChipButton(
                          label: 'Good',
                          color: Colors.orange,
                          onTap: onGood)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _RatingChipButton(
                          label: 'Easy', color: Colors.green, onTap: onEasy)),
                ],
              )
            : SizedBox(
                key: const ValueKey('flip'),
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onFlip,
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text('Show Answer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  const _RatingChipButton(
      {required this.label, required this.color, required this.onTap});

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
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color.withOpacity(0.7))),
      ],
    );
  }
}