import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/flashcards_provider.dart';
import '../services/deck_service.dart';
import '../widgets/study_deck_widget.dart';

/// Flashcards screen - equivalent to app/flashcards/page.tsx
/// Main screen for managing and studying flashcard decks
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Fetch decks on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlashcardsProvider>().fetchDeckInfos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlashcardsProvider>(
      builder: (context, provider, _) {
        // Study mode
        if (provider.isStudying && provider.studyingDeck != null) {
          return StudyDeckWidget(
            deck: provider.studyingDeck!,
            studySessionId: provider.studySessionId,
            availableCards: provider.availableCards,
            nextSessionDate: provider.nextSessionDate,
            conversationId: provider.conversationId,
            onExit: provider.exitStudy,
            provider: provider,
          );
        }

        // Main content
        return _buildMainContent(context, provider);
      },
    );
  }

  Widget _buildMainContent(BuildContext context, FlashcardsProvider provider) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Loading state
    if (provider.isLoading && provider.deckInfos.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (provider.error != null && provider.deckInfos.isEmpty) {
      return _buildErrorState(context, provider, l10n, colorScheme);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.fetchDeckInfos,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(context, l10n, colorScheme),
            ),

            // Empty state or content
            if (provider.deckInfos.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(context, provider, l10n, colorScheme),
              )
            else ...[
              // Search and filter bar
              SliverToBoxAdapter(
                child: _buildSearchAndFilterBar(context, provider, l10n, colorScheme),
              ),

              // Deck grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: MediaQuery.of(context).size.width > 600
                        ? 1.5
                        : 1.3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final deckInfo = provider.filteredDeckInfos[index];
                      return _DeckCard(
                        deckInfo: deckInfo,
                        onStudy: () => _handleStudy(context, provider, deckInfo),
                        onEdit: () => _showEditDeckDialog(context, provider, deckInfo),
                        onDelete: () => _showDeleteConfirmation(context, provider, deckInfo),
                        onShare: () => _handleShare(context, provider, deckInfo),
                        onRemoveShared: () => _handleRemoveShared(context, provider, deckInfo),
                      );
                    },
                    childCount: provider.filteredDeckInfos.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: provider.deckInfos.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDeckDialog(context, provider),
              icon: const Icon(Icons.add),
              label: Text(l10n?.createDeck ?? 'Create Deck'),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations? l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          // Title
          Text(
            l10n?.flashcards ?? 'Flashcards',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            l10n?.flashcardsDescription ??
                'Create and study flashcard decks to boost your learning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading decks...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    FlashcardsProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.error ?? 'Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.error ?? l10n?.errorOccurred ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  provider.clearError();
                  provider.fetchDeckInfos();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.try_again ?? 'Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    FlashcardsProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.welcome_flashcards ?? 'Welcome to Flashcards',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.get_started_create_deck ??
                  'Create your first deck or add one using a share code',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _showCreateDeckDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: Text(l10n?.create_your_first_deck ?? 'Create Deck'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _showAddByCodeDialog(context, provider),
                  icon: const Icon(Icons.download),
                  label: Text(l10n?.addByCode ?? 'Add by Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    FlashcardsProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: l10n?.searchDecks ?? 'Search decks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
            onChanged: provider.setSearchQuery,
          ),
          const SizedBox(height: 12),

          // Filter and action buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sort dropdown
                _SortDropdown(
                  sortBy: provider.sortBy,
                  onChanged: provider.setSortBy,
                ),
                const SizedBox(width: 8),

                // Sort direction
                IconButton.outlined(
                  onPressed: provider.toggleSortDirection,
                  icon: Icon(
                    provider.sortDirection == SortDirection.asc
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                  tooltip: provider.sortDirection == SortDirection.asc
                      ? l10n?.ascending ?? 'Ascending'
                      : l10n?.descending ?? 'Descending',
                ),
                const SizedBox(width: 8),

                // Add by code
                OutlinedButton.icon(
                  onPressed: () => _showAddByCodeDialog(context, provider),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(l10n?.addByCode ?? 'Add by Code'),
                ),
                const SizedBox(width: 8),

                // Manage shares
                OutlinedButton.icon(
                  onPressed: () => _showManageSharesDialog(context, provider),
                  icon: const Icon(Icons.people, size: 18),
                  label: Text(l10n?.manageShares ?? 'Manage Shares'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _handleStudy(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    final success = await provider.startStudy(deckInfo);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to start study session'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    final shareCode = await provider.shareDeck(deckInfo.id);
    if (shareCode != null && mounted) {
      await Clipboard.setData(ClipboardData(text: shareCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share code copied: $shareCode'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareCode));
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleRemoveShared(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.removeSharedDeck ?? 'Remove Shared Deck'),
        content: Text(
          l10n?.removeSharedDeckConfirm ??
              'Are you sure you want to remove this shared deck from your library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.remove ?? 'Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.removeSharedDeck(deckInfo.id);
    }
  }

  void _showCreateDeckDialog(BuildContext context, FlashcardsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _EditDeckDialog(
        onSave: (name, description, flashcards) async {
          final success = await provider.createDeck(
            name: name,
            description: description,
            flashcards: flashcards,
          );
          if (success && mounted) {
            Navigator.pop(context);
          }
          return success;
        },
      ),
    );
  }

  void _showEditDeckDialog(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    // Track if loading dialog is still showing
    bool isLoadingDialogOpen = true;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => PopScope(
        canPop: false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    ).then((_) {
      isLoadingDialogOpen = false;
    });

    Deck? deck;
    String? errorMessage;

    try {
      // Fetch full deck with flashcards
      final deckService = DeckService();
      deck = await deckService.fetchDeck(deckInfo.id);
    } catch (e) {
      errorMessage = e.toString();
    }

    // Close loading indicator only if it's still open and widget is mounted
    if (isLoadingDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading deck: $errorMessage')),
      );
      return;
    }

    if (deck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load deck')),
      );
      return;
    }

    // Show edit dialog with full deck
    showDialog(
      context: context,
      builder: (editDialogContext) => _EditDeckDialog(
        deck: deck,
        onSave: (name, description, flashcards) async {
          final success = await provider.updateDeck(
            deckId: deck!.id,
            name: name,
            description: description,
            flashcards: flashcards,
          );
          if (success) {
            Navigator.of(editDialogContext).pop();
          }
          return success;
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteDeck ?? 'Delete Deck'),
        content: Text(
          l10n?.deleteDeckConfirm(deckInfo.name) ??
              'Are you sure you want to delete "${deckInfo.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteDeck(deckInfo.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.deckDeleted ?? 'Deck deleted'),
          ),
        );
      }
    }
  }

  void _showAddByCodeDialog(BuildContext context, FlashcardsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _AddByCodeDialog(provider: provider),
    );
  }

  void _showManageSharesDialog(BuildContext context, FlashcardsProvider provider) {
    provider.fetchMySharedCodes();
    showDialog(
      context: context,
      builder: (context) => _ManageSharesDialog(provider: provider),
    );
  }
}

// ============================================================================
// DECK CARD WIDGET
// ============================================================================

class _DeckCard extends StatefulWidget {
  final DeckInfo deckInfo;
  final VoidCallback onStudy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onRemoveShared;

  const _DeckCard({
    required this.deckInfo,
    required this.onStudy,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onRemoveShared,
  });

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  OverdueStats? _overdueStats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadOverdueStats();
  }

  Future<void> _loadOverdueStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await DeckService().getOverdueStats(widget.deckInfo.id);
      if (mounted) {
        setState(() {
          _overdueStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading overdue stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isShared = widget.deckInfo.accessType == 'shared' || widget.deckInfo.isOwn == false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onStudy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.deckInfo.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Card count and badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.style,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.deckInfo.flashcardCount} ${l10n?.cards ?? 'cards'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (isShared)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n?.shared ?? 'Shared',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            // Overdue badge
                            if (_overdueStats != null && _overdueStats!.overdueCards > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 12,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_overdueStats!.overdueCards} overdue',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Due today badge
                            if (_overdueStats != null && _overdueStats!.dueToday > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.today,
                                      size: 12,
                                      color: colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_overdueStats!.dueToday} due',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onTertiaryContainer,
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
                  // Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEdit();
                          break;
                        case 'delete':
                          widget.onDelete();
                          break;
                        case 'share':
                          widget.onShare();
                          break;
                        case 'remove_shared':
                          widget.onRemoveShared();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isShared) ...[
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n?.edit ?? 'Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              const Icon(Icons.share, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n?.share ?? 'Share'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                l10n?.delete ?? 'Delete',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        PopupMenuItem(
                          value: 'remove_shared',
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle, size: 18, color: colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                l10n?.removeFromLibrary ?? 'Remove from library',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Description
              if (widget.deckInfo.description != null && widget.deckInfo.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    widget.deckInfo.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),

              // Footer with overdue breakdown
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overdue breakdown (if available)
                  if (_overdueStats != null && _overdueStats!.overdueCards > 0) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_overdueStats!.overdueBreakdown.veryOverdue > 0)
                          _buildOverdueBadge(
                            context,
                            '${_overdueStats!.overdueBreakdown.veryOverdue} very overdue (>7d)',
                            Colors.red.shade100,
                            Colors.red.shade900,
                          ),
                        if (_overdueStats!.overdueBreakdown.moderatelyOverdue > 0)
                          _buildOverdueBadge(
                            context,
                            '${_overdueStats!.overdueBreakdown.moderatelyOverdue} overdue (3-7d)',
                            Colors.orange.shade100,
                            Colors.orange.shade900,
                          ),
                        if (_overdueStats!.overdueBreakdown.slightlyOverdue > 0)
                          _buildOverdueBadge(
                            context,
                            '${_overdueStats!.overdueBreakdown.slightlyOverdue} overdue (1-2d)',
                            Colors.amber.shade100,
                            Colors.amber.shade900,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Last session and study button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.deckInfo.lastSession != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(widget.deckInfo.lastSession!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),

                      // Study button
                      FilledButton.icon(
                        onPressed: widget.onStudy,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: Text(l10n?.study ?? 'Study'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
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

  Widget _buildOverdueBadge(BuildContext context, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return dateString;

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

// ============================================================================
// SORT DROPDOWN
// ============================================================================

class _SortDropdown extends StatelessWidget {
  final DeckSortOption sortBy;
  final Function(DeckSortOption) onChanged;

  const _SortDropdown({
    required this.sortBy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<DeckSortOption>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 8),
            Text(_getSortLabel(sortBy, l10n)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DeckSortOption.name,
          child: Text(l10n?.name ?? 'Name'),
        ),
        PopupMenuItem(
          value: DeckSortOption.cards,
          child: Text(l10n?.cardCount ?? 'Card Count'),
        ),
        PopupMenuItem(
          value: DeckSortOption.recent,
          child: Text(l10n?.recent ?? 'Recent'),
        ),
        PopupMenuItem(
          value: DeckSortOption.lastSession,
          child: Text(l10n?.lastSession ?? 'Last Session'),
        ),
      ],
    );
  }

  String _getSortLabel(DeckSortOption option, AppLocalizations? l10n) {
    switch (option) {
      case DeckSortOption.name:
        return l10n?.name ?? 'Name';
      case DeckSortOption.cards:
        return l10n?.cardCount ?? 'Cards';
      case DeckSortOption.recent:
        return l10n?.recent ?? 'Recent';
      case DeckSortOption.lastSession:
        return l10n?.lastSession ?? 'Last Session';
    }
  }
}

// ============================================================================
// EDIT DECK DIALOG
// ============================================================================

class _EditDeckDialog extends StatefulWidget {
  final Future<bool> Function(String name, String? description, List<Flashcard> flashcards) onSave;
  final Deck? deck;

  const _EditDeckDialog({
    required this.onSave,
    this.deck,
  });

  @override
  State<_EditDeckDialog> createState() => _EditDeckDialogState();
}

class _EditDeckDialogState extends State<_EditDeckDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<_FlashcardInput> _flashcards = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.deck != null) {
      _nameController.text = widget.deck!.name;
      _descriptionController.text = widget.deck!.description ?? '';
      _flashcards = widget.deck!.flashcards
          .map((f) => _FlashcardInput(
                question: f.question,
                answer: f.answer,
              ))
          .toList();
    }
    if (_flashcards.isEmpty) {
      _flashcards.add(_FlashcardInput());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addFlashcard() {
    setState(() {
      _flashcards.add(_FlashcardInput());
    });
  }

  void _removeFlashcard(int index) {
    if (_flashcards.length > 1) {
      setState(() {
        _flashcards.removeAt(index);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final flashcards = _flashcards
        .where((f) => f.question.isNotEmpty && f.answer.isNotEmpty)
        .map((f) => Flashcard(
              question: f.question,
              answer: f.answer,
            ))
        .toList();

    if (flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one flashcard')),
      );
      setState(() => _isSaving = false);
      return;
    }

    await widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      flashcards,
    );

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    widget.deck != null
                        ? l10n?.editDeck ?? 'Edit Deck'
                        : l10n?.createDeck ?? 'Create Deck',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n?.deckName ?? 'Deck Name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n?.nameRequired ?? 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n?.description ?? 'Description (optional)',
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Flashcards
                      Row(
                        children: [
                          Text(
                            l10n?.flashcards ?? 'Flashcards',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addFlashcard,
                            icon: const Icon(Icons.add),
                            label: Text(l10n?.addCard ?? 'Add Card'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Flashcard list
                      ...List.generate(_flashcards.length, (index) {
                        return _FlashcardInputWidget(
                          key: ValueKey(index),
                          input: _flashcards[index],
                          index: index + 1,
                          canDelete: _flashcards.length > 1,
                          onDelete: () => _removeFlashcard(index),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n?.cancel ?? 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n?.save ?? 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardInput {
  String question;
  String answer;

  _FlashcardInput({this.question = '', this.answer = ''});
}

class _FlashcardInputWidget extends StatelessWidget {
  final _FlashcardInput input;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;

  const _FlashcardInputWidget({
    super.key,
    required this.input,
    required this.index,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${l10n?.card ?? 'Card'} $index',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    color: Theme.of(context).colorScheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: input.question,
              decoration: InputDecoration(
                labelText: l10n?.question ?? 'Question',
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => input.question = value,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: input.answer,
              decoration: InputDecoration(
                labelText: l10n?.answer ?? 'Answer',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => input.answer = value,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ADD BY CODE DIALOG
// ============================================================================

class _AddByCodeDialog extends StatefulWidget {
  final FlashcardsProvider provider;

  const _AddByCodeDialog({required this.provider});

  @override
  State<_AddByCodeDialog> createState() => _AddByCodeDialogState();
}

class _AddByCodeDialogState extends State<_AddByCodeDialog> {
  final _codeController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = widget.provider;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n?.addDeckByCode ?? 'Add Deck by Code'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n?.shareCode ?? 'Share Code',
                hintText: 'XXXXXXXXXXXX',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              onChanged: (value) {
                if (value.length == 12) {
                  provider.getShareCodeInfo(value);
                } else {
                  provider.clearShareCodeInfo();
                }
              },
            ),
            const SizedBox(height: 16),

            // Share code info
            ListenableBuilder(
              listenable: provider,
              builder: (context, _) {
                if (provider.isShareCodeLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final info = provider.shareCodeInfo;
                if (info == null) return const SizedBox.shrink();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${info.itemCount} cards • by ${info.creatorName}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        if (info.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            info.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (info.alreadyAdded == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                l10n?.alreadyAdded ?? 'Already in your library',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            provider.clearShareCodeInfo();
            Navigator.pop(context);
          },
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: _isAdding || _codeController.text.length != 12
              ? null
              : () async {
                  setState(() => _isAdding = true);
                  final success = await provider.addDeckByCode(
                    _codeController.text.trim(),
                  );
                  setState(() => _isAdding = false);
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n?.deckAddedSuccessfully ??
                            'Deck added successfully'),
                      ),
                    );
                  }
                },
          child: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n?.add ?? 'Add'),
        ),
      ],
    );
  }
}

// ============================================================================
// MANAGE SHARES DIALOG
// ============================================================================

class _ManageSharesDialog extends StatelessWidget {
  final FlashcardsProvider provider;

  const _ManageSharesDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n?.manageShares ?? 'Manage Shared Decks'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            if (provider.mySharedCodes.isEmpty) {
              return Center(
                child: Text(
                  l10n?.noSharedDecks ?? 'No shared decks yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: provider.mySharedCodes.length,
              itemBuilder: (context, index) {
                final code = provider.mySharedCodes[index];
                return ListTile(
                  title: Text(code.contentName),
                  subtitle: Text('${code.itemCount} cards • ${code.accessCount} uses'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code.shareCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code copied: ${code.shareCode}'),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await provider.deactivateShareCode(code.shareCode);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    );
  }
}

