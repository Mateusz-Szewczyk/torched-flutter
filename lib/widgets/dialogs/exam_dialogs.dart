import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../providers/exams_provider.dart';
import '../../l10n/app_localizations.dart';
import 'base_glass_dialog.dart';
import '../common/glass_components.dart';

// ============================================================================
// EDIT EXAM DIALOG
// ============================================================================

class EditExamDialog extends StatefulWidget {
  final Future<bool> Function(String name, String description, List<ExamQuestion> questions) onSave;
  final Exam? exam;

  const EditExamDialog({
    super.key,
    required this.onSave,
    this.exam,
  });

  static Future<void> show(BuildContext context, {
    required Future<bool> Function(String, String, List<ExamQuestion>) onSave,
    Exam? exam,
  }) {
    return BaseGlassDialog.show(
      context,
      maxWidth: 600,
      title: exam != null ? (AppLocalizations.of(context)?.editExam ?? 'Edit Exam') : (AppLocalizations.of(context)?.createExam ?? 'Create Exam'),
      child: EditExamDialog(onSave: onSave, exam: exam),
    );
  }

  @override
  State<EditExamDialog> createState() => _EditExamDialogState();
}

class _EditExamDialogState extends State<EditExamDialog> {
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.nameRequired ?? 'Name is required')),
      );
      return;
    }

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

    // Ensure at least one correct answer per question if questions are valid
    // (Optional: enforce this validation logic depending on requirements)

    final success = await widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim(),
      questions,
    );
    
    // We let the parent handle navigation or we assume success keeps dialog open? 
    // Usually we close on success.
    // If onSave returns true, we can signal completion if we were responsible for closing.
    // But BaseGlassDialog.show is a future.
    
    if (mounted) {
       setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Dialog structure handled by BaseGlassDialog wrapper static method
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            // padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GhostTextField(
                  controller: _nameController,
                  labelText: l10n?.examName ?? 'Exam Name',
                  prefixIcon: Icons.title,
                ),
                const SizedBox(height: 16),
                GhostTextField(
                  controller: _descriptionController,
                  labelText: l10n?.description ?? 'Description (optional)',
                  prefixIcon: Icons.description,
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _QuestionInputWidget(
                      key: ValueKey(index),
                      input: _questions[index],
                      index: index + 1,
                      canDelete: _questions.length > 1,
                      onDelete: () => _removeQuestion(index),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(l10n?.save ?? 'Save Exam'),
            ),
          ],
        ),
      ],
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

    return GlassTile(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
                GhostTextField(
                  initialValue: widget.input.text,
                  labelText: l10n?.questionText ?? 'Question text',
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
                          child: GhostTextField(
                            initialValue: answer.text,
                            hintText: '${l10n?.answer ?? 'Answer'} ${String.fromCharCode(65 + answerIndex)}',
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
// ADD EXAM BY CODE DIALOG
// ============================================================================

class AddExamByCodeDialog extends StatefulWidget {
  final ExamsProvider provider;

  const AddExamByCodeDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, ExamsProvider provider) {
    return BaseGlassDialog.show(
      context,
      maxWidth: 420,
      title: AppLocalizations.of(context)?.addExamByCode ?? 'Add Exam by Code',
      child: AddExamByCodeDialog(provider: provider),
    );
  }

  @override
  State<AddExamByCodeDialog> createState() => _AddExamByCodeDialogState();
}

class _AddExamByCodeDialogState extends State<AddExamByCodeDialog> {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GhostTextField(
          controller: _codeController,
          labelText: l10n?.shareCode ?? 'Share Code',
          hintText: 'XXXXXXXXXXXX',
          prefixIcon: Icons.key,
          maxLength: 12,
          onChanged: (value) {
            final upper = value.toUpperCase();
            if (upper != value) {
                _codeController.value = _codeController.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                );
                return;
            }
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
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
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
              );
            }

            if (info == null) return const SizedBox.shrink();

            return GlassTile(
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
            );
          },
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                provider.clearShareCodeInfo();
                Navigator.pop(context);
              },
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            const SizedBox(width: 8),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(l10n?.add ?? 'Add'),
                  );
                }
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// MANAGE SHARES DIALOG
// ============================================================================

class ManageExamSharesDialog extends StatelessWidget {
  final ExamsProvider provider;

  const ManageExamSharesDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, ExamsProvider provider) {
    provider.fetchMySharedCodes();
    return BaseGlassDialog.show(
      context,
      maxWidth: 600,
      title: AppLocalizations.of(context)?.manageShares ?? 'Manage Shared Exams',
      child: ManageExamSharesDialog(provider: provider),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays < 30) {
        return '${(diff.inDays / 7).floor()} weeks ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share codes you created',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListenableBuilder(
              listenable: provider,
              builder: (context, _) {
                if (provider.mySharedCodes.isEmpty) {
                  return _buildEmptyState(context, colorScheme, l10n);
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.mySharedCodes.length,
                  itemBuilder: (context, index) {
                    final code = provider.mySharedCodes[index];
                    return _ExamShareCodeCard(
                      code: code,
                      contentTypeLabel: 'questions',
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: code.shareCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Copied: ${code.shareCode}')),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: colorScheme.primary,
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirm = await GlassConfirmationDialog.show(
                          context,
                          title: 'Deactivate Share Code?',
                          content: 'This will prevent others from using code "${code.shareCode}" to add this exam. '
                              'Users who already added it will keep their copy.',
                          confirmLabel: 'Deactivate',
                          isDestructive: true,
                        );
                        if (confirm == true) {
                          await provider.deactivateShareCode(code.shareCode);
                        }
                      },
                      formatDate: _formatDate,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.share_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n?.noSharedDecks ?? 'No shared exams yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share an exam to generate a code that others can use to add it to their library.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExamShareCodeCard extends StatefulWidget {
  final MySharedCode code;
  final String contentTypeLabel; // 'cards' or 'questions'
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final String Function(String) formatDate;

  const _ExamShareCodeCard({
    required this.code,
    required this.contentTypeLabel,
    required this.onCopy,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  State<_ExamShareCodeCard> createState() => _ExamShareCodeCardState();
}

class _ExamShareCodeCardState extends State<_ExamShareCodeCard> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassTile(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.code.contentName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          widget.contentTypeLabel == 'cards'
                              ? Icons.style_rounded
                              : Icons.quiz_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.code.itemCount} ${widget.contentTypeLabel}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.key, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    widget.code.shareCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: widget.onCopy,
                  tooltip: 'Copy code',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                widget.formatDate(widget.code.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),

              Icon(Icons.people_outline, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${widget.code.accessCount} ${widget.code.accessCount == 1 ? 'user' : 'users'}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isDeleting ? null : () async {
                  setState(() => _isDeleting = true);
                  await Future(() => widget.onDelete());
                  if (mounted) setState(() => _isDeleting = false);
                },
                icon: _isDeleting
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.error,
                  ),
                )
                    : Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                label: Text(
                  'Deactivate',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
