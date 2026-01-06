import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import '../services/category_service.dart';
import '../l10n/app_localizations.dart';
import 'dialogs/base_glass_dialog.dart';
import 'common/glass_components.dart';

/// Dialog for creating/editing a workspace
/// 
/// Uses [BaseGlassDialog] for consistent glassmorphism effect.
class WorkspaceFormDialog extends StatefulWidget {
  final WorkspaceModel? workspace; // null = create new, non-null = edit

  const WorkspaceFormDialog({
    super.key,
    this.workspace,
  });

  static Future<WorkspaceModel?> show(BuildContext context, {WorkspaceModel? workspace}) {
    return BaseGlassDialog.show<WorkspaceModel>(
      context,
      builder: (context) => WorkspaceFormDialog(workspace: workspace),
    );
  }

  @override
  State<WorkspaceFormDialog> createState() => _WorkspaceFormDialogState();
}

class _WorkspaceFormDialogState extends State<WorkspaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final WorkspaceService _workspaceService = WorkspaceService();
  final CategoryService _categoryService = CategoryService();

  List<CategoryModel> _availableCategories = [];
  Set<String> _selectedCategoryIds = {};
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // If editing, populate fields
    if (widget.workspace != null) {
      _nameController.text = widget.workspace!.name;
      _descriptionController.text = widget.workspace!.description ?? '';
      _selectedCategoryIds = widget.workspace!.categories
          .map((cat) => cat.id)
          .toSet();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      setState(() {
        _availableCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveWorkspace() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final WorkspaceModel result;

      if (widget.workspace == null) {
        // Create new
        result = await _workspaceService.createWorkspace(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryIds: _selectedCategoryIds.toList(),
        );
      } else {
        // Update existing
        result = await _workspaceService.updateWorkspace(
          workspaceId: widget.workspace!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryIds: _selectedCategoryIds.toList(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save workspace: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final isCreatingNotifier = ValueNotifier<bool>(false);

    final result = await showDialog<CategoryModel?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(l10n?.addNewCategory ?? 'New Category'),
          ],
        ),
        content: ValueListenableBuilder<bool>(
          valueListenable: isCreatingNotifier,
          builder: (context, isCreating, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                enabled: !isCreating,
                decoration: InputDecoration(
                  labelText: l10n?.categoryName ?? 'Category Name',
                  hintText: 'e.g., Biology, History',
                  prefixIcon: const Icon(Icons.folder_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                ),
                onSubmitted: isCreating ? null : (value) async {
                  if (value.trim().isNotEmpty) {
                    isCreatingNotifier.value = true;
                    try {
                      final newCategory = await _categoryService.createCategory(value.trim());
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(newCategory);
                      }
                    } catch (e) {
                      isCreatingNotifier.value = false;
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create category: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isCreatingNotifier,
            builder: (context, isCreating, _) => FilledButton(
              onPressed: isCreating ? null : () async {
                if (controller.text.trim().isNotEmpty) {
                  isCreatingNotifier.value = true;
                  try {
                    final newCategory = await _categoryService.createCategory(controller.text.trim());
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(newCategory);
                    }
                  } catch (e) {
                    isCreatingNotifier.value = false;
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create category: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n?.create ?? 'Create'),
            ),
          ),
        ],
      ),
    );

    // If a category was created, add it to the list and auto-select it
    if (result != null) {
      setState(() {
        _availableCategories.add(result);
        _selectedCategoryIds.add(result.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Category "${result.name}" created and selected'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.workspace != null;

    return BaseGlassDialog(
      title: isEditing ? (l10n?.editWorkspace ?? 'Edit Workspace') : (l10n?.createWorkspace ?? 'Create Workspace'),
      maxWidth: 700,
      maxHeight: 750,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              GhostTextField(
                controller: _nameController,
                labelText: l10n?.workspaceName ?? 'Workspace Name',
                hintText: 'e.g., Biology Notes',
                prefixIcon: Icons.label_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n?.nameRequired ?? 'Name is required';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 12),

              // Description field
              GhostTextField(
                controller: _descriptionController,
                labelText: l10n?.description ?? 'Description',
                hintText: l10n?.optional ?? 'Optional',
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),

              // Category selection section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Text(
                    l10n?.selectCategories ?? 'Categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the content areas for this workspace',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category chips container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(80),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isLoadingCategories
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _availableCategories.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.folder_off_outlined, size: 32, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No categories available',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              )
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  // Category chips
                                  ..._availableCategories.map((category) {
                                    final isSelected = _selectedCategoryIds.contains(category.id);
                                    return FilterChip(
                                      label: Text(category.name),
                                      avatar: Icon(
                                        category.isSystem ? Icons.folder_special_outlined : Icons.folder_outlined,
                                        size: 18,
                                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                      ),
                                      selected: isSelected,
                                      onSelected: _isLoading
                                          ? null
                                          : (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedCategoryIds.add(category.id);
                                                } else {
                                                  _selectedCategoryIds.remove(category.id);
                                                }
                                              });
                                            },
                                      checkmarkColor: colorScheme.onPrimary,
                                      selectedColor: colorScheme.primary,
                                      backgroundColor: colorScheme.surface,
                                      showCheckmark: false,
                                      labelStyle: TextStyle(
                                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    );
                                  }),
                                ],
                              ),
                  ),

                  // Add category button - separate from chips for clearer UX
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _showAddCategoryDialog,
                    icon: Icon(Icons.add_rounded, size: 18, color: colorScheme.primary),
                    label: Text(
                      'Create new category',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n?.cancel ?? 'Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveWorkspace,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing
                            ? (l10n?.save ?? 'Save')
                            : (l10n?.create ?? 'Create')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
