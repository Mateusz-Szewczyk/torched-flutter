import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/exams_provider.dart';
import '../services/exam_service.dart';
import '../widgets/study_exam_widget.dart';
import '../widgets/dialogs/base_glass_dialog.dart';
import '../widgets/dialogs/exam_dialogs.dart';

/// Exams screen - equivalent to app/tests/page.tsx
/// Main screen for managing and taking exams
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Desktop constraint
  static const double _kMaxContentWidth = 1000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamsProvider>().fetchExamInfos();
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
    return Consumer<ExamsProvider>(
      builder: (context, provider, _) {
        // Study mode
        if (provider.isStudying && provider.studyingExam != null) {
          return StudyExamWidget(
            exam: provider.studyingExam!,
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
          floatingActionButton: provider.examInfos.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () => _showCreateExamDialog(context, provider),
                  child: const Icon(Icons.add),
                  tooltip: AppLocalizations.of(context)?.createExam ?? 'Create Exam',
                )
              : null,
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, ExamsProvider provider) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Loading state
    if (provider.isLoading && provider.examInfos.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (provider.error != null && provider.examInfos.isEmpty) {
      return _buildErrorState(context, provider, l10n, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: provider.fetchExamInfos,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeaderAndActions(context, provider, l10n, colorScheme),
          ),

          // Empty state or content
          if (provider.examInfos.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context, provider, l10n, colorScheme),
            )
          else ...[
            // Search and filter bar
            SliverToBoxAdapter(
              child: _buildSearchAndFilterBar(context, provider, l10n, colorScheme),
            ),

            // Exam grid
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
                    final examInfo = provider.filteredExamInfos[index];
                    return _ExamCard(
                      examInfo: examInfo,
                      onStudy: () => _handleStudy(context, provider, examInfo),
                      onEdit: () => _showEditExamDialog(context, provider, examInfo),
                      onDelete: () => _showDeleteConfirmation(context, provider, examInfo),
                      onShare: () => _handleShare(context, provider, examInfo),
                      onRemoveShared: () => _handleRemoveShared(context, provider, examInfo),
                    );
                  },
                  childCount: provider.filteredExamInfos.length,
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

  Widget _buildHeaderAndActions(BuildContext context, ExamsProvider provider,
      AppLocalizations? l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.tests ?? 'Tests',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.testsDescription ?? 'Create and take practice exams to test your knowledge',
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
                  onPressed: () => _showCreateExamDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: Text(l10n?.createExam ?? 'Create Exam'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            'Loading exams...',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ExamsProvider provider,
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
                provider.fetchExamInfos();
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
    ExamsProvider provider,
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
              child: Icon(Icons.quiz_outlined, size: 48, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.welcomeTests ?? 'Welcome to Tests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.getStartedCreateTest ??
                  'Create your first exam or add one using a share code',
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
    ExamsProvider provider,
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
                    hintText: l10n?.searchExams ?? 'Search exams...',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),
              const SizedBox(width: 12),
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
              IconButton.filledTonal(
                onPressed: provider.toggleSortDirection,
                icon: Icon(
                  provider.sortDirection == SortDirection.asc
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                tooltip: provider.sortDirection == SortDirection.asc
                    ? 'Ascending'
                    : 'Descending',
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
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    final success = await provider.startStudy(examInfo);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to start exam'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    final shareCode = await provider.shareExam(examInfo.id);
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
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await GlassConfirmationDialog.show(
      context,
      title: l10n?.removeSharedExam ?? 'Remove Shared Exam',
      content: l10n?.removeSharedExamConfirm ??
          'Are you sure you want to remove this shared exam from your library?',
      confirmLabel: l10n?.remove ?? 'Remove',
      isDestructive: true,
    );

    if (confirmed == true) {
      await provider.removeSharedExam(examInfo.id);
    }
  }

  void _showCreateExamDialog(BuildContext context, ExamsProvider provider) {
    EditExamDialog.show(
      context,
      onSave: (name, description, questions) async {
        final success = await provider.createExam(
          name: name,
          description: description,
          questions: questions,
        );
        if (success && mounted) {
           Navigator.of(context).pop();
        }
        return success;
      },
    );
  }

  void _showEditExamDialog(
    BuildContext context,
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    bool isLoadingDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => PopScope(
        canPop: false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    ).then((_) {
      isLoadingDialogOpen = false;
    });

    Exam? exam;
    String? errorMessage;

    try {
      final examService = ExamService();
      exam = await examService.fetchExam(examInfo.id);
    } catch (e) {
      errorMessage = e.toString();
    }

    if (isLoadingDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading exam: $errorMessage')),
      );
      return;
    }

    if (exam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load exam')),
      );
      return;
    }

    EditExamDialog.show(
      context,
      exam: exam,
      onSave: (name, description, questions) async {
        final success = await provider.updateExam(
          examId: exam!.id,
          name: name,
          description: description,
          questions: questions,
        );
        if (success) {
          Navigator.of(context).pop();
        }
        return success;
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await GlassConfirmationDialog.show(
      context,
      title: l10n?.deleteExam ?? 'Delete Exam',
      content: 'Are you sure you want to delete "${examInfo.name}"? This cannot be undone.',
      confirmLabel: l10n?.delete ?? 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      final success = await provider.deleteExam(examInfo.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.examDeleted ?? 'Exam deleted')),
        );
      }
    }
  }

  void _showAddByCodeDialog(BuildContext context, ExamsProvider provider) {
    AddExamByCodeDialog.show(context, provider);
  }

  void _showManageSharesDialog(BuildContext context, ExamsProvider provider) {
    provider.fetchMySharedCodes();
    ManageExamSharesDialog.show(context, provider);
  }
}

// ============================================================================
// EXAM CARD WIDGET
// ============================================================================

class _ExamCard extends StatelessWidget {
  final ExamInfo examInfo;
  final VoidCallback onStudy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onRemoveShared;

  const _ExamCard({
    required this.examInfo,
    required this.onStudy,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onRemoveShared,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isShared = examInfo.accessType == 'shared' || examInfo.isOwn == false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStudy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examInfo.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (examInfo.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            examInfo.description,
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
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                        case 'share':
                          onShare();
                          break;
                        case 'remove_shared':
                          onRemoveShared();
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

              // Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    icon: Icons.quiz,
                    label: '${examInfo.questionCount}',
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
                ],
              ),

              const Spacer(),
              const Divider(height: 24),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: onStudy,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n?.startExam ?? 'Start'),
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
  final ExamSortOption sortBy;
  final Function(ExamSortOption) onChanged;

  const _SortDropdown({
    required this.sortBy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownButtonHideUnderline(
      child: DropdownButton<ExamSortOption>(
        value: sortBy,
        icon: const Icon(Icons.arrow_drop_down),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem(
            value: ExamSortOption.name,
            child: Text(l10n?.name ?? 'Name'),
          ),
          DropdownMenuItem(
            value: ExamSortOption.questions,
            child: Text(l10n?.questions ?? 'Questions'),
          ),
          DropdownMenuItem(
            value: ExamSortOption.recent,
            child: Text(l10n?.recent ?? 'Recent'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

