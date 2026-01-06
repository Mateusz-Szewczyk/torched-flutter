import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/flashcards_provider.dart';
import '../services/deck_service.dart';
import '../widgets/study_deck_widget.dart';
import '../widgets/dialogs/base_glass_dialog.dart';
import '../widgets/dialogs/flashcard_dialogs.dart';

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
    final confirmed = await GlassConfirmationDialog.show(
      context,
      title: l10n?.removeSharedDeck ?? 'Remove Shared Deck',
      content: l10n?.removeSharedDeckConfirm ??
          'Are you sure you want to remove this shared deck from your library?',
      confirmLabel: l10n?.remove ?? 'Remove',
      isDestructive: true,
    );

    if (confirmed == true) {
      await provider.removeSharedDeck(deckInfo.id);
    }
  }

  void _showCreateDeckDialog(
      BuildContext context, FlashcardsProvider provider) {
    EditDeckDialog.show(
      context,
      onSave: (name, description, flashcards) async {
        final success = await provider.createDeck(
          name: name,
          description: description,
          flashcards: flashcards,
        );
        if (success && mounted) {
           Navigator.pop(context); // Note: BaseGlassDialog usually closes on successful action in its child if implemented that way, but here we are passing onSave. 
           // Wait, the EditDeckDialog implementation I wrote calls onSave. The original code waited for onSave and then popped.
           // In my refactored EditDeckDialog, I didn't auto pop in onSave. 
           // IMPORTANT: BaseGlassDialog doesn't return the result of the child's logic directly unless we pass it.
           // My EditDeckDialog implementation calls onSave and updates state. It does NOT pop itself on success yet (I commented about it).
           // I should rely on the dialog popping itself or handle it here. 
           // Let's re-read my EditDeckDialog implementation.
           // It says: "if (mounted) setState(() => _isSaving = false);"
           // It does NOT pop. So I need to pop it inside EditDeckDialog or handle it. 
           // Actually, standard pattern is to return success.
           // Let's assume EditDeckDialog pops itself on success. 
           // Wait, I *did not* make it pop on success in the new file. I should have. 
           // I'll update EditDeckDialog in a subsequent step if needed, or I can rely on the fact that I passed `onSave` to it.
           // If I pass `onSave` to it, `EditDeckDialog` calls it. 
           // If `EditDeckDialog` doesn't pop, `_showCreateDeckDialog` can't pop it because it's not awaiting the result in the same way? 
           // `EditDeckDialog.show` returns a Future. 
           // The original code passed `onSave` which returned a boolean. The dialog itself called this `onSave` and popped if true.
           // My new `EditDeckDialog` calls `widget.onSave`. It does NOT pop.
           // I made a mistake in `EditDeckDialog`. It should pop on success.
           // I will fix `EditDeckDialog` in a separate step. For now, let's assume `EditDeckDialog` will handle the logic or I will pass a wrapper that pops.
           // Actually, `Navigator.pop(context)` in `_showCreateDeckDialog` (lines 474) was inside the `onSave` callback!
           // The original `_EditDeckDialog` called the callback, and the callback popped the context provided by `showDialog`? No, `Navigator.pop(context)` uses the context captured in `_showCreateDeckDialog`.
           // But `showDialog` pushes a new route. So `context` in `_showCreateDeckDialog` is the parent context. popping that would close the screen? NO. `Navigator.pop(context)` uses the *build context* of the method?
           // No, `Navigator.pop(context)` pops the top-most route *if* context is not specific?
           // No, `Navigator.pop(context)` pops the route that `context` is in?
           // If `context` is `FlashcardsScreen`, pop would pop the screen.
           // THIS IS A BUG IN ORIGINAL CODE? 
           // Line 474: `Navigator.pop(context);` where `context` is the argument to `_showCreateDeckDialog`.
           // `showDialog` pushes a dialog route. 
           // If you call `Navigator.pop(parentContext)`, it might work if the dialog is the top route? No.
           // Wait, `builder: (context) => ...`. The original code used `context` from `builder`.
           // Ah, line 474 uses `context` which is... wait.
           // `builder: (context) => _EditDeckDialog(...)`. The `context` used in `Navigator.pop(context)` is SHADOWED by the builder's context?
           // No, `onSave: (name...) async { ... Navigator.pop(context); }`. The `context` here is the one from `_showCreateDeckDialog` arguments?
           // If so, it would close the SCREEN, not the dialog?
           // Unless `_showCreateDeckDialog` is called with a builder context?
           // `FlashcardsScreen` calls `_showCreateDeckDialog(context, provider)`.
           // So `context` is `FlashcardsScreen`'s context.
           // `Navigator.pop(context)` would pop the screen.
           // BUT, `_EditDeckDialog` was probably calling `onSave` and expecting it to close the dialog.
           // Let's look at `_EditDeckDialog` original code again.
           // `await widget.onSave(...)`. It doesn't pop.
           // So the original code might have been buggy or relying on something else.
           // OR `Navigator.pop` works on the Navigator of the context.
           // `Navigator.of(context).pop()` pops the top-most route of the navigator.
           // So if a dialog is open, it pops the dialog. Even if you pass the parent context.
           // YES. `Navigator.pop(context)` is just `Navigator.of(context).pop()`.
           // So passing `onSave` that does `Navigator.pop` works.
           
           // So, my refactoring in `FlashcardsScreen`:
           // `EditDeckDialog.show(context, onSave: (name, desc, cards) async { ... Navigator.of(context).pop(); return success; })`
           // But wait, `EditDeckDialog.show` inside `flashcard_dialogs.dart` pushes the dialog.
           // The `onSave` is executed.
           // If I call `Navigator.of(context).pop()` inside `onSave` where `context` is `FlashcardsScreen` context, it will pop the top route (the dialog).
           // So it SHOULD work.
           return success; 
        }
        return success;
      },
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

    EditDeckDialog.show(
      context,
      deck: deck,
      onSave: (name, description, flashcards) async {
        final success = await provider.updateDeck(
          deckId: deck!.id,
          name: name,
          description: description,
          flashcards: flashcards,
        );
        if (success) {
          // Find the dialog context or use root navigator to pop?
          // The context passed here is 'editDialogContext' in original code, but now we don't have it exposed directly in the builder.
          // But as discussed, Navigator.pop(context) using parent context pops the top route.
          // However, EditDeckDialog.show calls BaseGlassDialog.show which pushes a route.
          Navigator.of(context).pop();
        }
        return success;
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    FlashcardsProvider provider,
    DeckInfo deckInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await GlassConfirmationDialog.show(
      context,
      title: l10n?.deleteDeck ?? 'Delete Deck',
      content: l10n?.deleteDeckConfirm(deckInfo.name) ??
          'Are you sure you want to delete "${deckInfo.name}"? This cannot be undone.',
      confirmLabel: l10n?.delete ?? 'Delete',
      isDestructive: true,
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
    AddFlashcardDeckByCodeDialog.show(context, provider);
  }

  void _showManageSharesDialog(
      BuildContext context, FlashcardsProvider provider) {
    provider.fetchMySharedCodes();
    ManageFlashcardSharesDialog.show(context, provider);
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
      debugPrint('[DeckCard] Loading overdue stats for deck ID: ${widget.deckInfo.id}, name: ${widget.deckInfo.name}');
      final stats = await DeckService().getOverdueStats(widget.deckInfo.id);
      debugPrint('[DeckCard] Stats loaded for deck ${widget.deckInfo.id}: totalCards=${stats?.totalCards}, dueToday=${stats?.dueToday}, overdue=${stats?.overdueCards}');
      if (mounted) {
        setState(() {
          _overdueStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('[DeckCard] Error loading overdue stats for deck ${widget.deckInfo.id}: $e');
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
                  // Show cards due today (scheduled for today)
                  if (_overdueStats != null && _overdueStats!.dueToday > 0)
                    _Badge(
                      icon: Icons.today_rounded,
                      label: '${_overdueStats!.dueToday} today',
                      color: colorScheme.primary,
                      bgColor: colorScheme.primaryContainer,
                      textColor: colorScheme.onPrimaryContainer,
                    ),
                  // Show overdue cards (past their review date)
                  if (_overdueStats != null && _overdueStats!.overdueCards > 0)
                    _Badge(
                      icon: Icons.warning_amber_rounded,
                      label: '${_overdueStats!.overdueCards} overdue',
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

