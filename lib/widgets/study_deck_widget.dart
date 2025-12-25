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
/// Features: swipe gestures, 3D flip cards, haptic feedback, celebratory animations
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
  _SwipeDirection? _swipeHint;

  // Stats tracking
  int _easyCount = 0;
  int _goodCount = 0;
  int _hardCount = 0;

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
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutBack),
    );

    // Swipe animation
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Celebration animation
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
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  /// Handle swipe start
  void _onPanStart(DragStartDetails details) {
    _swipeController.stop();
  }

  /// Handle swipe update
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;

      // Determine swipe hint based on position
      if (_dragX.abs() > 30 || _dragY.abs() > 30) {
        if (_dragX < -50) {
          _swipeHint = _SwipeDirection.left; // Hard
        } else if (_dragX > 50) {
          _swipeHint = _SwipeDirection.right; // Easy
        } else if (_dragY < -50) {
          _swipeHint = _SwipeDirection.up; // Good
        } else {
          _swipeHint = null;
        }
      } else {
        _swipeHint = null;
      }
    });
  }

  /// Handle swipe end
  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    final threshold = 100.0;

    if (_isFlipped) {
      // Swipe to rate
      if (_dragX < -threshold || velocity.dx < -500) {
        _animateSwipeOut(_SwipeDirection.left, () => _handleRating(0)); // Hard
      } else if (_dragX > threshold || velocity.dx > 500) {
        _animateSwipeOut(_SwipeDirection.right, () => _handleRating(5)); // Easy
      } else if (_dragY < -threshold || velocity.dy < -500) {
        _animateSwipeOut(_SwipeDirection.up, () => _handleRating(3)); // Good
      } else {
        _resetSwipe();
      }
    } else {
      // If not flipped, flip on tap/slight swipe
      if (_dragX.abs() < 20 && _dragY.abs() < 20) {
        _handleFlip();
      }
      _resetSwipe();
    }
  }

  void _animateSwipeOut(_SwipeDirection direction, VoidCallback onComplete) {
    HapticFeedback.mediumImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double targetX = _dragX;
    double targetY = _dragY;

    switch (direction) {
      case _SwipeDirection.left:
        targetX = -screenWidth * 1.5;
        break;
      case _SwipeDirection.right:
        targetX = screenWidth * 1.5;
        break;
      case _SwipeDirection.up:
        targetY = -screenHeight;
        break;
    }

    // Animate out
    _swipeController.reset();
    final startX = _dragX;
    final startY = _dragY;

    _swipeController.addListener(() {
      setState(() {
        _dragX = startX + (targetX - startX) * _swipeController.value;
        _dragY = startY + (targetY - startY) * _swipeController.value;
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
      _swipeHint = null;
    });
  }

  /// Handle rating (0 = hard, 3 = medium, 5 = easy)
  void _handleRating(int rating) {
    if (_cardsQueue.isEmpty) return;

    final currentCard = _cardsQueue[_currentIndex];

    // Track stats
    if (rating == 0) _hardCount++;
    else if (rating == 3) _goodCount++;
    else if (rating == 5) _easyCount++;

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
      _celebrationController.forward();
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
      HapticFeedback.heavyImpact();
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
    HapticFeedback.mediumImpact();
    final success = await widget.provider.retakeHardCards();
    if (success && widget.provider.availableCards.isNotEmpty) {
      setState(() {
        _cardsQueue = _shuffle(List.from(widget.provider.availableCards));
        _currentIndex = 0;
        _isFlipped = false;
        _localRatings = [];
        _initialTotalCards = _cardsQueue.length;
        _cardSeenCount = {};
        _easyCount = 0;
        _goodCount = 0;
        _hardCount = 0;
        for (var card in _cardsQueue) {
          _cardSeenCount[card.id ?? 0] = 0;
        }
      });
      _flipController.reset();
      _celebrationController.reset();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.noHardCardsFound ??
                'No hard cards found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Handle retake full session
  Future<void> _handleRetakeSession() async {
    HapticFeedback.mediumImpact();
    final success = await widget.provider.retakeSession();
    if (success && widget.provider.availableCards.isNotEmpty) {
      setState(() {
        _cardsQueue = _shuffle(List.from(widget.provider.availableCards));
        _currentIndex = 0;
        _isFlipped = false;
        _localRatings = [];
        _initialTotalCards = _cardsQueue.length;
        _cardSeenCount = {};
        _easyCount = 0;
        _goodCount = 0;
        _hardCount = 0;
        for (var card in _cardsQueue) {
          _cardSeenCount[card.id ?? 0] = 0;
        }
      });
      _flipController.reset();
      _celebrationController.reset();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.noCardsToRetake ??
                'No cards to retake'),
            behavior: SnackBarBehavior.floating,
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // Session complete view
    if (_cardsQueue.isEmpty) {
      return _buildSessionComplete(context, l10n, colorScheme, isMobile);
    }

    final currentCard = _cardsQueue[_currentIndex];
    final progress = _initialTotalCards > 0
        ? ((_initialTotalCards - _cardsQueue.length) / _initialTotalCards)
        : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            _buildAppBar(context, l10n, colorScheme, progress),

            // Card area with swipe gestures
            Expanded(
              child: Stack(
                children: [
                  // Swipe hint overlays
                  if (_swipeHint != null && _isFlipped)
                    _buildSwipeHintOverlay(colorScheme),

                  // Main card
                  GestureDetector(
                    onTap: _isFlipped ? null : _handleFlip,
                    onPanStart: _isFlipped ? _onPanStart : null,
                    onPanUpdate: _isFlipped ? _onPanUpdate : null,
                    onPanEnd: _isFlipped ? _onPanEnd : null,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(_dragX, _dragY),
                        child: Transform.rotate(
                          angle: _dragX * 0.001,
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 32),
                            child: _buildFlipCard(currentCard, colorScheme, theme, isMobile),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom controls
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomControls(context, l10n, colorScheme, isMobile),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onExit,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 12),

              // Title and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.deck.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_initialTotalCards - _cardsQueue.length} / $_initialTotalCards',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats pills
              _buildStatsPill(Icons.check, _easyCount, Colors.green),
              const SizedBox(width: 4),
              _buildStatsPill(Icons.trending_flat, _goodCount, Colors.orange),
              const SizedBox(width: 4),
              _buildStatsPill(Icons.refresh, _hardCount, Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPill(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHintOverlay(ColorScheme colorScheme) {
    Color overlayColor;
    IconData icon;
    String label;
    Alignment alignment;

    switch (_swipeHint) {
      case _SwipeDirection.left:
        overlayColor = Colors.red;
        icon = Icons.replay;
        label = 'Hard';
        alignment = Alignment.centerLeft;
        break;
      case _SwipeDirection.right:
        overlayColor = Colors.green;
        icon = Icons.check;
        label = 'Easy';
        alignment = Alignment.centerRight;
        break;
      case _SwipeDirection.up:
        overlayColor = Colors.orange;
        icon = Icons.trending_up;
        label = 'Good';
        alignment = Alignment.topCenter;
        break;
      default:
        return const SizedBox.shrink();
    }

    final opacity = (_dragX.abs() + _dragY.abs()) / 200;

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          alignment: alignment,
          padding: const EdgeInsets.all(32),
          child: AnimatedOpacity(
            opacity: opacity.clamp(0.0, 1.0),
            duration: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: overlayColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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

  Widget _buildFlipCard(Flashcard card, ColorScheme colorScheme, ThemeData theme, bool isMobile) {
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
                  isQuestion: true,
                  colorScheme: colorScheme,
                  theme: theme,
                  isMobile: isMobile,
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildCardFace(
                    content: card.answer,
                    isQuestion: false,
                    colorScheme: colorScheme,
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
    required bool isQuestion,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isMobile,
  }) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: isMobile ? 350 : 400,
        maxHeight: isMobile ? 500 : 550,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isQuestion
              ? [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.6),
                ]
              : [
                  colorScheme.secondaryContainer,
                  colorScheme.secondaryContainer.withValues(alpha: 0.6),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isQuestion ? colorScheme.primary : colorScheme.secondary)
                .withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 32),
          child: Column(
            children: [
              // Header with label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isQuestion ? colorScheme.primary : colorScheme.secondary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isQuestion ? Icons.help_outline : Icons.lightbulb_outline,
                          size: 18,
                          color: isQuestion ? colorScheme.primary : colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isQuestion
                              ? (l10n?.question ?? 'Question')
                              : (l10n?.answer ?? 'Answer'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isQuestion ? colorScheme.primary : colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        content,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: isQuestion
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSecondaryContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom hint
              if (isQuestion && !_isFlipped)
                _buildTapHint(colorScheme, l10n)
              else if (!isQuestion)
                _buildSwipeInstructions(colorScheme, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapHint(ColorScheme colorScheme, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            l10n?.tapToFlip ?? 'Tap to reveal answer',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeInstructions(ColorScheme colorScheme, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwipeHintMini(Icons.arrow_back, Colors.red, 'Hard'),
          const SizedBox(width: 12),
          _buildSwipeHintMini(Icons.arrow_upward, Colors.orange, 'Good'),
          const SizedBox(width: 12),
          _buildSwipeHintMini(Icons.arrow_forward, Colors.green, 'Easy'),
        ],
      ),
    );
  }

  Widget _buildSwipeHintMini(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface.withValues(alpha: 0),
            colorScheme.surface,
          ],
        ),
      ),
      child: _isFlipped
          ? _buildRatingButtons(context, l10n, colorScheme, isMobile)
          : _buildFlipButton(context, l10n, colorScheme),
    );
  }

  Widget _buildFlipButton(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _handleFlip,
        icon: const Icon(Icons.flip),
        label: Text(
          l10n?.showAnswer ?? 'Show Answer',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingButtons(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme, bool isMobile) {
    return Row(
      children: [
        // Hard
        Expanded(
          child: _RatingButton(
            icon: Icons.replay,
            label: l10n?.hard ?? 'Hard',
            subtitle: l10n?.tryAgain ?? 'Again',
            color: Colors.red,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleRating(0);
            },
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 8),
        // Good
        Expanded(
          child: _RatingButton(
            icon: Icons.trending_up,
            label: l10n?.good ?? 'Good',
            subtitle: l10n?.reviewLater ?? 'Later',
            color: Colors.orange,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleRating(3);
            },
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 8),
        // Easy
        Expanded(
          child: _RatingButton(
            icon: Icons.check,
            label: l10n?.easy ?? 'Easy',
            subtitle: l10n?.gotIt ?? 'Got it!',
            color: Colors.green,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleRating(5);
            },
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionComplete(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme, bool isMobile) {
    final totalReviewed = _easyCount + _goodCount + _hardCount;
    final accuracy = totalReviewed > 0 ? ((_easyCount + _goodCount) / totalReviewed * 100).round() : 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) {
            return Stack(
              children: [
                // Confetti effect (simple version)
                if (_celebrationController.isAnimating)
                  ...List.generate(20, (i) {
                    final random = Random(i);
                    return Positioned(
                      left: random.nextDouble() * MediaQuery.of(context).size.width,
                      top: -50 + (_celebrationController.value * (MediaQuery.of(context).size.height + 100)),
                      child: Transform.rotate(
                        angle: _celebrationController.value * 10 + i,
                        child: Icon(
                          Icons.star,
                          color: [Colors.amber, Colors.pink, Colors.blue, Colors.green][i % 4],
                          size: 20 + random.nextDouble() * 20,
                        ),
                      ),
                    );
                  }),

                // Main content
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 24 : 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Trophy icon with animation
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade300,
                                      Colors.amber.shade600,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(alpha: 0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  size: 72,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          l10n?.sessionComplete ?? 'Session Complete!',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Great job studying ${widget.deck.name}!',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Stats cards
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              // Main stat
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$accuracy%',
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accuracy',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Breakdown
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.check_circle,
                                    label: 'Easy',
                                    count: _easyCount,
                                    color: Colors.green,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.trending_up,
                                    label: 'Good',
                                    count: _goodCount,
                                    color: Colors.orange,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.replay,
                                    label: 'Hard',
                                    count: _hardCount,
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (_submitError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _submitError!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Action buttons
                        Column(
                          children: [
                            // Save & Exit (primary)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting ? null : _handleFinish,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  l10n?.saveAndExit ?? 'Save & Exit',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Retake options
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleRetakeSession,
                                    icon: const Icon(Icons.refresh, size: 20),
                                    label: const Text('Retake All'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleRetakeHardCards,
                                    icon: Icon(Icons.replay, size: 20, color: Colors.red.shade400),
                                    label: Text(
                                      'Hard Only',
                                      style: TextStyle(color: Colors.red.shade400),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: Colors.red.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Exit without saving
                            TextButton(
                              onPressed: widget.onExit,
                              child: Text(
                                l10n?.backToDecks ?? 'Back to Decks',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// Swipe direction enum
enum _SwipeDirection { left, right, up }

/// Rating button widget - larger and more touch-friendly
class _RatingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;
  final bool isMobile;

  const _RatingButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 16 : 20,
            horizontal: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 24 : 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: isMobile ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

