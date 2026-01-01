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

  // Desktop constraint
  static const double _kMaxContentWidth = 1000.0;

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
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              child: _buildMainContent(context, provider),
            ),
          ),
          // Keep FAB for mobile convenience
          floatingActionButton: provider.deckInfos.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () => _showCreateDeckDialog(context, provider),
                  child: const Icon(Icons.add),
                  tooltip:
                      AppLocalizations.of(context)?.createDeck ?? 'Create Deck',
                )
              : null,
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, FlashcardsProvider provider) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Loading state
    if (provider.isLoading && provider.deckInfos.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (provider.error != null && provider.deckInfos.isEmpty) {
      return _buildErrorState(context, provider, l10n, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: provider.fetchDeckInfos,
      child: CustomScrollView(
        slivers: [
          // Header with Title and Actions
          SliverToBoxAdapter(
            child: _buildHeaderAndActions(context, provider, l10n, colorScheme),
          ),

          // Empty state or content
          if (provider.deckInfos.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context, provider, l10n, colorScheme),
            )
          else ...[
            // Search and filter bar
            SliverToBoxAdapter(
              child: _buildSearchAndFilterBar(
                  context, provider, l10n, colorScheme),
            ),

            // Deck grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  childAspectRatio: MediaQuery.of(context).size.width > 600
                      ? 1.6
                      : 1.4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final deckInfo = provider.filteredDeckInfos[index];
                    return _DeckCard(
                      deckInfo: deckInfo,
                      onStudy: () => _handleStudy(context, provider, deckInfo),
                      onEdit: () =>
                          _showEditDeckDialog(context, provider, deckInfo),
                      onDelete: () =>
                          _showDeleteConfirmation(context, provider, deckInfo),
                      onShare: () => _handleShare(context, provider, deckInfo),
                      onRemoveShared: () =>
                          _handleRemoveShared(context, provider, deckInfo),
                    );
                  },
                  childCount: provider.filteredDeckInfos.length,
                ),
              ),
            ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderAndActions(BuildContext context, FlashcardsProvider provider,
      AppLocalizations? l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.flashcards ?? 'Flashcards',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.flashcardsDescription ??
                'Create and study flashcard decks to boost your learning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Action Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _showCreateDeckDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: Text(l10n?.createDeck ?? 'Create Deck'),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showAddByCodeDialog(context, provider),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n?.addByCode ?? 'Add by Code'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showManageSharesDialog(context, provider),
                  icon: const Icon(Icons.people_outline),
                  label: Text(l10n?.manageShares ?? 'Shared'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
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
    );
  }

  Widget _buildErrorState(
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
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.style_outlined,
                  size: 48, color: colorScheme.primary),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
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
                    fillColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _SortDropdown(
                  sortBy: provider.sortBy,
                  onChanged: provider.setSortBy,
                ),
              ),
              const SizedBox(width: 8),
              // Sort direction
              IconButton.filledTonal(
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
            ],
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
          behavior: SnackBarBehavior.floating,
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

  void _showCreateDeckDialog(
      BuildContext context, FlashcardsProvider provider) {
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
    bool isLoadingDialogOpen = true;

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
      final deckService = DeckService();
      deck = await deckService.fetchDeck(deckInfo.id);
    } catch (e) {
      errorMessage = e.toString();
    }

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
            behavior: SnackBarBehavior.floating,
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

  void _showManageSharesDialog(
      BuildContext context, FlashcardsProvider provider) {
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
    final isShared =
        widget.deckInfo.accessType == 'shared' || widget.deckInfo.isOwn == false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onStudy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title & Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.deckInfo.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.deckInfo.description != null &&
                            widget.deckInfo.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.deckInfo.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: colorScheme.onSurfaceVariant),
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
                              Icon(Icons.delete,
                                  size: 18, color: colorScheme.error),
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
                              Icon(Icons.remove_circle,
                                  size: 18, color: colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                l10n?.removeFromLibrary ?? 'Remove',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    icon: Icons.style,
                    label: '${widget.deckInfo.flashcardCount}',
                    color: colorScheme.secondary,
                    bgColor: colorScheme.secondaryContainer,
                    textColor: colorScheme.onSecondaryContainer,
                  ),
                  if (isShared)
                    _Badge(
                      icon: Icons.people,
                      label: l10n?.shared ?? 'Shared',
                      color: colorScheme.tertiary,
                      bgColor: colorScheme.tertiaryContainer,
                      textColor: colorScheme.onTertiaryContainer,
                    ),
                  if (_overdueStats != null && _overdueStats!.overdueCards > 0)
                    _Badge(
                      icon: Icons.warning_amber_rounded,
                      label: '${_overdueStats!.overdueCards} due',
                      color: colorScheme.error,
                      bgColor: colorScheme.errorContainer,
                      textColor: colorScheme.onErrorContainer,
                    ),
                ],
              ),

              const Spacer(),
              const Divider(height: 24),

              // Bottom Row: Date & Action
              Row(
                children: [
                  if (widget.deckInfo.lastSession != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.lastSession ?? 'Last studied',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _formatDate(widget.deckInfo.lastSession!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: widget.onStudy,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n?.study ?? 'Study'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return dateString;

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}';
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color textColor;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
    return DropdownButtonHideUnderline(
      child: DropdownButton<DeckSortOption>(
        value: sortBy,
        icon: const Icon(Icons.arrow_drop_down),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem(
            value: DeckSortOption.name,
            child: Text(l10n?.name ?? 'Name'),
          ),
          DropdownMenuItem(
            value: DeckSortOption.cards,
            child: Text(l10n?.cardCount ?? 'Card Count'),
          ),
          DropdownMenuItem(
            value: DeckSortOption.recent,
            child: Text(l10n?.recent ?? 'Recent'),
          ),
          DropdownMenuItem(
            value: DeckSortOption.lastSession,
            child: Text(l10n?.lastSession ?? 'Last Session'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ============================================================================
// EDIT DECK DIALOG
// ============================================================================

class _EditDeckDialog extends StatefulWidget {
  final Future<bool> Function(
          String name, String? description, List<Flashcard> flashcards) onSave;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n?.deckName ?? 'Deck Name',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n?.nameRequired ?? 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n?.description ?? 'Description (optional)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n?.flashcards ?? 'Flashcards',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addFlashcard,
                            icon: const Icon(Icons.add),
                            label: Text(l10n?.addCard ?? 'Add Card'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n?.cancel ?? 'Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n?.save ?? 'Save Deck'),
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  '#$index',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                ),
                const Spacer(),
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(20),
                    child: Icon(Icons.close, size: 20, color: cs.error),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  initialValue: input.question,
                  decoration: InputDecoration(
                    labelText: l10n?.question ?? 'Question',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: cs.surface,
                  ),
                  onChanged: (value) => input.question = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: input.answer,
                  decoration: InputDecoration(
                    labelText: l10n?.answer ?? 'Answer',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: cs.surface,
                  ),
                  maxLines: 2,
                  onChanged: (value) => input.answer = value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD BY CODE DIALOG (FIXED)
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
    widget.provider.clearShareCodeInfo();
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
                prefixIcon: const Icon(Icons.key),
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

                // Handle 404 / Invalid Code state
                if (info == null && _codeController.text.length == 12 && !provider.isShareCodeLoading) {
                  return Card(
                    elevation: 0,
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Invalid or expired code',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (info == null) return const SizedBox.shrink();

                // Show valid deck info card
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold),
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l10n?.alreadyAdded ?? 'Already in your library',
                                  style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (info.isOwnDeck == true) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: colorScheme.secondary),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'This is your own deck',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
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
            Navigator.pop(context);
          },
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final info = provider.shareCodeInfo;
            final isInvalid = _codeController.text.length != 12;

            // Fix: Handle nullable booleans with ?? false
            final isAlreadyAdded = info?.alreadyAdded ?? false;
            final isOwnDeck = info?.isOwnDeck ?? false;

            // Logic: Disable if loading, invalid format, already added, own deck, or info is missing (404)
            final shouldDisable = _isAdding || isInvalid || isAlreadyAdded || isOwnDeck || info == null;

            return FilledButton(
              onPressed: shouldDisable
                  ? null
                  : () async {
                      setState(() => _isAdding = true);
                      provider.clearError();

                      final success = await provider.addDeckByCode(
                        _codeController.text.trim().toUpperCase(),
                      );

                      if (!mounted) return;
                      setState(() => _isAdding = false);

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n?.deckAddedSuccessfully ??
                                'Deck added successfully'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.error ?? 'Failed to add deck'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: colorScheme.error,
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
            );
          },
        )
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.noSharedDecks ?? 'No shared decks yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: provider.mySharedCodes.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, index) {
                final code = provider.mySharedCodes[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(code.contentName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${code.itemCount} cards • ${code.accessCount} users'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: code.shareCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code copied: ${code.shareCode}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Theme.of(context).colorScheme.error,
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    );
  }
}