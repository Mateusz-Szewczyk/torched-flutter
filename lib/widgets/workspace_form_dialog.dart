import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import '../services/category_service.dart';
import '../l10n/app_localizations.dart';

/// Dialog for creating/editing a workspace
class WorkspaceFormDialog extends StatefulWidget {
  final WorkspaceModel? workspace; // null = create new, non-null = edit

  const WorkspaceFormDialog({
    super.key,
    this.workspace,
  });

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.workspace != null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.work_outline,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Workspace' : 'Create Workspace',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workspace Name',
                    hintText: 'e.g., Biology Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n?.description ?? 'Description',
                    hintText: 'Optional',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),

                // Category selection section
                Text(
                  'Select Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which categories to include in this workspace. Only files from selected categories will be visible.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Categories chips
                if (_isLoadingCategories)
                  const Center(child: CircularProgressIndicator())
                else if (_availableCategories.isEmpty)
                  Text(
                    'No categories available',
                    style: TextStyle(color: colorScheme.error),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableCategories.map((category) {
                      final isSelected = _selectedCategoryIds.contains(category.id);
                      // Determine colors based on selection state for good contrast
                      final labelColor = isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface;
                      final iconColor = isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant;

                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.isSystem ? Icons.lock : Icons.folder,
                              size: 16,
                              color: iconColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              category.name,
                              style: TextStyle(color: labelColor),
                            ),
                          ],
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
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        showCheckmark: true,
                        side: isSelected
                            ? BorderSide.none
                            : BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(l10n?.cancel ?? 'Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _saveWorkspace,
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
                              : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
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

