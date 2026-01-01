import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/exams_provider.dart';
import '../services/exam_service.dart';
import '../widgets/study_exam_widget.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.removeSharedExam ?? 'Remove Shared Exam'),
        content: Text(
          l10n?.removeSharedExamConfirm ??
              'Are you sure you want to remove this shared exam from your library?',
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
      await provider.removeSharedExam(examInfo.id);
    }
  }

  void _showCreateExamDialog(BuildContext context, ExamsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _EditExamDialog(
        onSave: (name, description, questions) async {
          final success = await provider.createExam(
            name: name,
            description: description,
            questions: questions,
          );
          if (success && mounted) {
            Navigator.pop(context);
          }
          return success;
        },
      ),
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

    showDialog(
      context: context,
      builder: (editDialogContext) => _EditExamDialog(
        exam: exam,
        onSave: (name, description, questions) async {
          final success = await provider.updateExam(
            examId: exam!.id,
            name: name,
            description: description,
            questions: questions,
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
    ExamsProvider provider,
    ExamInfo examInfo,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteExam ?? 'Delete Exam'),
        content: Text(
          'Are you sure you want to delete "${examInfo.name}"? This cannot be undone.',
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
      final success = await provider.deleteExam(examInfo.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.examDeleted ?? 'Exam deleted')),
        );
      }
    }
  }

  void _showAddByCodeDialog(BuildContext context, ExamsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _AddByCodeDialog(provider: provider),
    );
  }

  void _showManageSharesDialog(BuildContext context, ExamsProvider provider) {
    provider.fetchMySharedCodes();
    showDialog(
      context: context,
      builder: (context) => _ManageSharesDialog(provider: provider),
    );
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

// ============================================================================
// EDIT EXAM DIALOG
// ============================================================================

class _EditExamDialog extends StatefulWidget {
  final Future<bool> Function(String name, String description, List<ExamQuestion> questions) onSave;
  final Exam? exam;

  const _EditExamDialog({
    required this.onSave,
    this.exam,
  });

  @override
  State<_EditExamDialog> createState() => _EditExamDialogState();
}

class _EditExamDialogState extends State<_EditExamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<_QuestionInput> _questions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.exam != null) {
      _nameController.text = widget.exam!.name;
      _descriptionController.text = widget.exam!.description;
      _questions = widget.exam!.questions.map((q) => _QuestionInput(
        id: q.id,
        text: q.text,
        answers: q.answers.map((a) => _AnswerInput(
          id: a.id,
          text: a.text,
          isCorrect: a.isCorrect,
        )).toList(),
      )).toList();
    }
    if (_questions.isEmpty) {
      _questions.add(_QuestionInput.empty());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionInput.empty());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final questions = _questions
        .where((q) => q.text.isNotEmpty && q.answers.any((a) => a.text.isNotEmpty))
        .map((q) => ExamQuestion(
              id: q.id,
              text: q.text,
              answers: q.answers
                  .where((a) => a.text.isNotEmpty)
                  .map((a) => ExamAnswer(
                        id: a.id,
                        text: a.text,
                        isCorrect: a.isCorrect,
                      ))
                  .toList(),
            ))
        .toList();

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question with answers')),
      );
      setState(() => _isSaving = false);
      return;
    }

    await widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim(),
      questions,
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
                    widget.exam != null
                        ? l10n?.editExam ?? 'Edit Exam'
                        : l10n?.createExam ?? 'Create Exam',
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
                          labelText: l10n?.examName ?? 'Exam Name',
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
                            l10n?.questions ?? 'Questions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addQuestion,
                            icon: const Icon(Icons.add),
                            label: Text(l10n?.addQuestion ?? 'Add Question'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_questions.length, (index) {
                        return _QuestionInputWidget(
                          key: ValueKey(index),
                          input: _questions[index],
                          index: index + 1,
                          canDelete: _questions.length > 1,
                          onDelete: () => _removeQuestion(index),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

class _QuestionInput {
  int? id;
  String text;
  List<_AnswerInput> answers;

  _QuestionInput({this.id, this.text = '', List<_AnswerInput>? answers})
      : answers = answers ?? [];

  factory _QuestionInput.empty() {
    return _QuestionInput(
      answers: [
        _AnswerInput(isCorrect: true),
        _AnswerInput(),
        _AnswerInput(),
        _AnswerInput(),
      ],
    );
  }
}

class _AnswerInput {
  int? id;
  String text;
  bool isCorrect;

  _AnswerInput({this.id, this.text = '', this.isCorrect = false});
}

class _QuestionInputWidget extends StatefulWidget {
  final _QuestionInput input;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;

  const _QuestionInputWidget({
    super.key,
    required this.input,
    required this.index,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  State<_QuestionInputWidget> createState() => _QuestionInputWidgetState();
}

class _QuestionInputWidgetState extends State<_QuestionInputWidget> {
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  '${l10n?.question ?? 'Question'} ${widget.index}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                ),
                const Spacer(),
                if (widget.canDelete)
                  InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(20),
                    child: Icon(Icons.close, size: 20, color: cs.error),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: widget.input.text,
                  decoration: InputDecoration(
                    labelText: l10n?.questionText ?? 'Question text',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: cs.surface,
                  ),
                  maxLines: 2,
                  onChanged: (value) => widget.input.text = value,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.answers ?? 'Answers (Select correct one)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...widget.input.answers.asMap().entries.map((entry) {
                  final answerIndex = entry.key;
                  final answer = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: answerIndex,
                          groupValue: widget.input.answers.indexWhere((a) => a.isCorrect),
                          onChanged: (value) {
                            setState(() {
                              for (var a in widget.input.answers) {
                                a.isCorrect = false;
                              }
                              if (value != null) {
                                widget.input.answers[value].isCorrect = true;
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: answer.text,
                            decoration: InputDecoration(
                              hintText: '${l10n?.answer ?? 'Answer'} ${String.fromCharCode(65 + answerIndex)}',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: cs.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) => answer.text = value,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD BY CODE DIALOG
// ============================================================================

class _AddByCodeDialog extends StatefulWidget {
  final ExamsProvider provider;

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
      title: Text(l10n?.addExamByCode ?? 'Add Exam by Code'),
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
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${info.itemCount} questions • by ${info.creatorName ?? 'Unknown'}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        if (info.description != null && info.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            info.description!,
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
                                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (info.isOwnExam == true) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: colorScheme.secondary),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'This is your own exam',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
            provider.clearShareCodeInfo();
            Navigator.pop(context);
          },
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final info = provider.shareCodeInfo;
            final isInvalid = _codeController.text.length != 12;

            final isAlreadyAdded = info?.alreadyAdded ?? false;
            final isOwnExam = info?.isOwnExam ?? false;

            final shouldDisable = _isAdding || isInvalid || isAlreadyAdded || isOwnExam || info == null;

            return FilledButton(
              onPressed: shouldDisable
                  ? null
                  : () async {
                      setState(() => _isAdding = true);
                      provider.clearError();

                      final success = await provider.addExamByCode(
                        _codeController.text.trim().toUpperCase(),
                      );

                      if (!mounted) return;
                      setState(() => _isAdding = false);

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n?.examAddedSuccessfully ??
                                'Exam added successfully'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.error ?? 'Failed to add exam'),
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
          }
        ),
      ],
    );
  }
}

// ============================================================================
// MANAGE SHARES DIALOG
// ============================================================================

class _ManageSharesDialog extends StatelessWidget {
  final ExamsProvider provider;

  const _ManageSharesDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n?.manageShares ?? 'Manage Shared Exams'),
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
                      l10n?.noSharedExams ?? 'No shared exams yet',
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
                  title: Text(code.contentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${code.itemCount} questions • ${code.accessCount} users'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code.shareCode));
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