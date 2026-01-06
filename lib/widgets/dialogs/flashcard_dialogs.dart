import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../providers/flashcards_provider.dart';
import '../../l10n/app_localizations.dart';
import 'base_glass_dialog.dart';
import '../common/glass_components.dart';

// ============================================================================
// EDIT DECK DIALOG
// ============================================================================

class EditDeckDialog extends StatefulWidget {
  final Future<bool> Function(
      String name, String? description, List<Flashcard> flashcards) onSave;
  final Deck? deck;

  const EditDeckDialog({
    super.key,
    required this.onSave,
    this.deck,
  });

  static Future<void> show(BuildContext context, {
    required Future<bool> Function(String, String?, List<Flashcard>) onSave,
    Deck? deck,
  }) {
    return BaseGlassDialog.show(
      context,
      maxWidth: 600,
      title: deck != null ? (AppLocalizations.of(context)?.editDeck ?? 'Edit Deck') : (AppLocalizations.of(context)?.createDeck ?? 'Create Deck'),
      child: EditDeckDialog(onSave: onSave, deck: deck),
    );
  }

  @override
  State<EditDeckDialog> createState() => _EditDeckDialogState();
}

class _EditDeckDialogState extends State<EditDeckDialog> {
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
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.nameRequired ?? 'Name is required')),
      );
      return;
    }

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

    final success = await widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      flashcards,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      // Main dialog logic usually handles closure, but we can manually pop if needed.
      // However, BaseGlassDialog content is just the child. The 'show' logic returns when dialog closes.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The Dialog structure is handled by BaseGlassDialog, so we just return the content column
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
                  labelText: l10n?.deckName ?? 'Deck Name',
                  prefixIcon: Icons.title,
                ),
                const SizedBox(height: 16),
                GhostTextField(
                  controller: _descriptionController,
                  labelText: l10n?.description ?? 'Description (optional)',
                  prefixIcon: Icons.description,
                  maxLines: 3,
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _FlashcardInputWidget(
                        key: ValueKey(index), // Note: Using index as key is risky if reordering, but fine for append/remove-end here. Better use unique key if possible.
                        input: _flashcards[index],
                        index: index + 1,
                        canDelete: _flashcards.length > 1,
                        onDelete: () => _removeFlashcard(index),
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
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(l10n?.save ?? 'Save Deck'),
            ),
          ],
        ),
      ],
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

    return GlassTile(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(15)), // Match GlassTile radius roughly
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
                GhostTextField(
                  initialValue: input.question,
                  labelText: l10n?.question ?? 'Question',
                  onChanged: (value) => input.question = value,
                ),
                const SizedBox(height: 12),
                GhostTextField(
                  initialValue: input.answer,
                  labelText: l10n?.answer ?? 'Answer',
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
// ADD BY CODE DIALOG
// ============================================================================

class AddFlashcardDeckByCodeDialog extends StatefulWidget {
  final FlashcardsProvider provider;

  const AddFlashcardDeckByCodeDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, FlashcardsProvider provider) {
    return BaseGlassDialog.show(
      context,
      maxWidth: 420,
      title: AppLocalizations.of(context)?.addDeckByCode ?? 'Add Deck by Code',
      child: AddFlashcardDeckByCodeDialog(provider: provider),
    );
  }

  @override
  State<AddFlashcardDeckByCodeDialog> createState() => _AddFlashcardDeckByCodeDialogState();
}

class _AddFlashcardDeckByCodeDialogState extends State<AddFlashcardDeckByCodeDialog> {
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
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.itemCount} cards${info.creatorName != null ? ' • by ${info.creatorName}' : ''}',
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
                  // Determine if button should be disabled
                  final info = provider.shareCodeInfo;
                  final isInvalid = _codeController.text.length != 12;
                  final isAlreadyAdded = info?.alreadyAdded ?? false;
                  final isOwnDeck = info?.isOwnDeck ?? false;

                  final shouldDisable = _isAdding || isInvalid || info == null || isAlreadyAdded || isOwnDeck;

                  return FilledButton(
                    onPressed: shouldDisable
                        ? null
                        : () async {
                      setState(() => _isAdding = true);

                      // Clear any previous errors
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

class ManageFlashcardSharesDialog extends StatelessWidget {
  final FlashcardsProvider provider;

  const ManageFlashcardSharesDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, FlashcardsProvider provider) {
    provider.fetchMySharedCodes();
    return BaseGlassDialog.show(
      context,
      maxWidth: 600,
      title: AppLocalizations.of(context)?.manageShares ?? 'Manage Shared Decks',
      child: ManageFlashcardSharesDialog(provider: provider),
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
                  // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: provider.mySharedCodes.length,
                  itemBuilder: (context, index) {
                    final code = provider.mySharedCodes[index];
                    return _ShareCodeCard(
                      code: code,
                      contentTypeLabel: 'cards',
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
                          content: 'This will prevent others from using code "${code.shareCode}" to add this deck. '
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
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
            l10n?.noSharedDecks ?? 'No shared decks yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share a deck to generate a code that others can use to add it to their library.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ShareCodeCard extends StatefulWidget {
  final MySharedCode code;
  final String contentTypeLabel; // 'cards' or 'questions'
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final String Function(String) formatDate;

  const _ShareCodeCard({
    required this.code,
    required this.contentTypeLabel,
    required this.onCopy,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  State<_ShareCodeCard> createState() => _ShareCodeCardState();
}

class _ShareCodeCardState extends State<_ShareCodeCard> {
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
          // Title and item count row
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

          // Share code display
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

          // Stats and actions row
          Row(
            children: [
              // Created date
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

              // Access count
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

              // Delete button
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
