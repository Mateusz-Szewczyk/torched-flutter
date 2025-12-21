import 'dart:math';
import 'package:flutter/material.dart';
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

/// Study deck widget - equivalent to StudyDeck.tsx component
/// Implements spaced repetition study with 3D flip cards
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
    with SingleTickerProviderStateMixin {
  late List<Flashcard> _cardsQueue;
  late int _initialTotalCards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isSubmitting = false;
  String? _submitError;
  List<FlashcardRating> _localRatings = [];
  Map<int, int> _cardSeenCount = {};

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _cardsQueue = _shuffle(List.from(widget.availableCards));
    _initialTotalCards = _cardsQueue.length;

    // Initialize seen count
    for (var card in widget.availableCards) {
      _cardSeenCount[card.id ?? 0] = 0;
    }

    // Flip animation
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// Shuffle cards using Fisher-Yates algorithm
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

  /// Handle flip card
  void _handleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  /// Handle rating (0 = hard, 3 = medium, 5 = easy)
  void _handleRating(int rating) {
    if (_cardsQueue.isEmpty) return;

    final currentCard = _cardsQueue[_currentIndex];

    // Add rating to local list
    _localRatings.add(FlashcardRating(
      flashcardId: currentCard.id ?? 0,
      rating: rating,
      answeredAt: DateTime.now().toIso8601String(),
    ));

    // Update card queue based on rating
    final updatedQueue = List<Flashcard>.from(_cardsQueue);
    if (rating == 0 || rating == 3) {
      // Hard or medium - move to end
      final removed = updatedQueue.removeAt(_currentIndex);
      updatedQueue.add(removed);
    } else if (rating == 5) {
      // Easy - remove from queue
      updatedQueue.removeAt(_currentIndex);
    }

    if (updatedQueue.isEmpty) {
      setState(() {
        _cardsQueue = [];
        _currentIndex = 0;
      });
      return;
    }

    int nextIndex = _currentIndex;
    if (nextIndex >= updatedQueue.length) {
      nextIndex = updatedQueue.length - 1;
    }

    // Update seen count for next card
    _cardSeenCount[updatedQueue[nextIndex].id ?? 0] =
        (_cardSeenCount[updatedQueue[nextIndex].id ?? 0] ?? 0) + 1;

    setState(() {
      _cardsQueue = updatedQueue;
      _currentIndex = nextIndex;
      _isFlipped = false;
    });

    // Reset flip animation
    _flipController.reset();
  }

  /// Handle finish session
  Future<void> _handleFinish() async {
    if (_localRatings.isEmpty) {
      widget.onExit();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final ratingsJson = _localRatings.map((r) => r.toJson()).toList();
      await widget.provider.submitRatings(ratingsJson);
      widget.onExit();
    } catch (e) {
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Handle retake hard cards
  Future<void> _handleRetakeHardCards() async {
    final success = await widget.provider.retakeHardCards();
    if (success && widget.provider.availableCards.isNotEmpty) {
      setState(() {
        _cardsQueue = _shuffle(List.from(widget.provider.availableCards));
        _currentIndex = 0;
        _isFlipped = false;
        _localRatings = [];
        _initialTotalCards = _cardsQueue.length;
        _cardSeenCount = {};
        for (var card in _cardsQueue) {
          _cardSeenCount[card.id ?? 0] = 0;
        }
      });
      _flipController.reset();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.noHardCardsFound ??
                'No hard cards found'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Session complete view
    if (_cardsQueue.isEmpty) {
      return _buildSessionComplete(context, l10n, colorScheme);
    }

    final currentCard = _cardsQueue[_currentIndex];
    final progress = _initialTotalCards > 0
        ? ((_initialTotalCards - _cardsQueue.length) / _initialTotalCards)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onExit,
        ),
        title: Text(widget.deck.name),
        actions: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_initialTotalCards - _cardsQueue.length}/$_initialTotalCards',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),

          // Card area
          Expanded(
            child: GestureDetector(
              onTap: _handleFlip,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildFlipCard(currentCard, colorScheme, theme),
                ),
              ),
            ),
          ),

          // Rating buttons (only show when flipped)
          if (_isFlipped)
            _buildRatingButtons(context, l10n, colorScheme),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.close),
                  label: Text(l10n?.exit ?? 'Exit'),
                ),
                if (!_isFlipped)
                  ElevatedButton.icon(
                    onPressed: _handleFlip,
                    icon: const Icon(Icons.flip),
                    label: Text(l10n?.showAnswer ?? 'Show Answer'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipCard(Flashcard card, ColorScheme colorScheme, ThemeData theme) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * pi;
        final isFront = angle < pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: isFront
              ? _buildCardFace(
                  content: card.question,
                  label: AppLocalizations.of(context)?.question ?? 'Question',
                  colorScheme: colorScheme,
                  theme: theme,
                  isQuestion: true,
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildCardFace(
                    content: card.answer,
                    label: AppLocalizations.of(context)?.answer ?? 'Answer',
                    colorScheme: colorScheme,
                    theme: theme,
                    isQuestion: false,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCardFace({
    required String content,
    required String label,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isQuestion,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 300,
          maxHeight: 500,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isQuestion
                ? [
                    colorScheme.primaryContainer.withOpacity(0.3),
                    colorScheme.surface,
                  ]
                : [
                    colorScheme.secondaryContainer.withOpacity(0.3),
                    colorScheme.surface,
                  ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isQuestion
                    ? colorScheme.primary.withOpacity(0.1)
                    : colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isQuestion
                      ? colorScheme.primary
                      : colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // Tap hint
            if (isQuestion && !_isFlipped)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)?.tapToFlip ?? 'Tap to flip',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButtons(
    BuildContext context,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Hard (0)
          Expanded(
            child: _RatingButton(
              label: l10n?.hard ?? 'Hard',
              subtitle: l10n?.tryAgain ?? 'Try again',
              color: colorScheme.error,
              onPressed: () => _handleRating(0),
            ),
          ),
          const SizedBox(width: 8),
          // Medium (3)
          Expanded(
            child: _RatingButton(
              label: l10n?.good ?? 'Good',
              subtitle: l10n?.reviewLater ?? 'Review later',
              color: colorScheme.tertiary,
              onPressed: () => _handleRating(3),
            ),
          ),
          const SizedBox(width: 8),
          // Easy (5)
          Expanded(
            child: _RatingButton(
              label: l10n?.easy ?? 'Easy',
              subtitle: l10n?.gotIt ?? 'Got it!',
              color: colorScheme.primary,
              onPressed: () => _handleRating(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionComplete(
    BuildContext context,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
        title: Text(widget.deck.name),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n?.sessionComplete ?? 'Session Complete!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Stats
              Text(
                l10n?.cardsReviewed(_initialTotalCards.toString()) ??
                    'You reviewed $_initialTotalCards cards',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              // Next session
              if (widget.nextSessionDate != null)
                Text(
                  l10n?.nextSession(widget.nextSessionDate!) ??
                      'Next session: ${widget.nextSessionDate}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),

              if (_submitError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _submitError!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],

              const SizedBox(height: 32),

              // Action buttons - Retake options
              Column(
                children: [
                  // Retake session button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleRetakeSession,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n?.retakeSession ?? 'Retake Session'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Retake hard cards button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleRetakeHardCards,
                      icon: const Icon(Icons.replay),
                      label: Text(l10n?.retakeHardCards ?? 'Retake Hard Cards'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Main action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_initialTotalCards > 0)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _handleFinish,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(l10n?.saveAndExit ?? 'Save & Exit'),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onExit,
                          icon: const Icon(Icons.arrow_back),
                          label: Text(l10n?.backToDecks ?? 'Back to Decks'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle retake full session
  Future<void> _handleRetakeSession() async {
    final success = await widget.provider.retakeSession();
    if (success && widget.provider.availableCards.isNotEmpty) {
      setState(() {
        _cardsQueue = _shuffle(List.from(widget.provider.availableCards));
        _currentIndex = 0;
        _isFlipped = false;
        _localRatings = [];
        _initialTotalCards = _cardsQueue.length;
        _cardSeenCount = {};
        for (var card in _cardsQueue) {
          _cardSeenCount[card.id ?? 0] = 0;
        }
      });
      _flipController.reset();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.noCardsToRetake ??
                'No cards to retake'),
          ),
        );
      }
    }
  }
}

/// Rating button widget
class _RatingButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

