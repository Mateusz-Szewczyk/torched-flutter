import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../services/category_service.dart';
import '../l10n/app_localizations.dart';
import 'dialogs/base_glass_dialog.dart';
import 'common/glass_components.dart';

/// Modern, beautiful category selector with adaptive UI for mobile and desktop
/// - Mobile: Bottom sheet selection
/// - Desktop: PopupMenu dropdown
class CategoryDropdown extends StatefulWidget {
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final bool isEnabled;
  final String? labelText;
  final String? hintText;
  final bool showLabel;
  final bool compact;

  const CategoryDropdown({
    super.key,
    this.selectedCategoryId,
    required this.onChanged,
    this.isEnabled = true,
    this.labelText,
    this.hintText,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  final CategoryService _categoryService = CategoryService();
  final GlobalKey _buttonKey = GlobalKey();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;
  bool _isHovering = false;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  CategoryModel? get _selectedCategory {
    if (widget.selectedCategoryId == null) return null;
    return _categories.where((c) => c.id == widget.selectedCategoryId).firstOrNull;
  }

  bool get _isDesktop {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 600;
  }

  void _showCategorySelector() {
    HapticFeedback.lightImpact();

    if (_isDesktop) {
      _showDesktopDropdown();
    } else {
      _showMobileBottomSheet();
    }
  }

  void _showDesktopDropdown() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    setState(() => _isDropdownOpen = true);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height + 4,
        screenSize.width - buttonPosition.dx - buttonSize.width,
        0,
      ),
      constraints: BoxConstraints(
        minWidth: buttonSize.width.clamp(280.0, 400.0),
        maxWidth: buttonSize.width.clamp(280.0, 400.0),
        maxHeight: 400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      items: _buildMenuItems(),
    ).then((value) {
      setState(() => _isDropdownOpen = false);
      if (value == '__add_new__') {
        _showAddCategoryDialog();
      } else if (value != null) {
        widget.onChanged(value);
      }
    });
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final systemCategories = _categories.where((c) => c.isSystem).toList();
    final userCategories = _categories.where((c) => !c.isSystem).toList();

    final List<PopupMenuEntry<String>> items = [];

    // User categories section
    if (userCategories.isNotEmpty) {
      items.add(PopupMenuItem<String>(
        enabled: false,
        height: 32,
        child: Text(
          (l10n?.myCategories ?? 'My Categories').toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 10,
          ),
        ),
      ));

      for (final category in userCategories) {
        items.add(_buildCategoryMenuItem(category, colorScheme, theme));
      }
    }

    // System categories section
    if (systemCategories.isNotEmpty) {
      if (userCategories.isNotEmpty) {
        items.add(const PopupMenuDivider(height: 8));
      }
      items.add(PopupMenuItem<String>(
        enabled: false,
        height: 32,
        child: Text(
          (l10n?.systemCategories ?? 'System').toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 10,
          ),
        ),
      ));

      for (final category in systemCategories) {
        items.add(_buildCategoryMenuItem(category, colorScheme, theme));
      }
    }

    // Add new button
    items.add(const PopupMenuDivider(height: 8));
    items.add(PopupMenuItem<String>(
      value: '__add_new__',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l10n?.addNewCategory ?? 'Add New Category',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ));

    return items;
  }

  PopupMenuItem<String> _buildCategoryMenuItem(
    CategoryModel category,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isSelected = category.id == widget.selectedCategoryId;

    return PopupMenuItem<String>(
      value: category.id,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withAlpha((255 * 0.5).round())
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withAlpha((255 * 0.15).round())
                    : category.isSystem
                        ? colorScheme.secondaryContainer.withAlpha((255 * 0.5).round())
                        : colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.isSystem ? Icons.folder_special_rounded : Icons.folder_rounded,
                size: 16,
                color: isSelected
                    ? colorScheme.primary
                    : category.isSystem
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  void _showMobileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategorySelectorSheet(
        categories: _categories,
        selectedCategoryId: widget.selectedCategoryId,
        onCategorySelected: (category) {
          widget.onChanged(category.id);
          Navigator.of(context).pop();
        },
        onAddNew: () async {
          Navigator.of(context).pop();
          await _showAddCategoryDialog();
        },
        onRefresh: _loadCategories,
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    
    // We use a ValueNotifier to handle local state without StatefulBuilder intricacies
    final isCreatingNotifier = ValueNotifier<bool>(false);

    final result = await BaseGlassDialog.show<CategoryModel>(
      context,
      child: ValueListenableBuilder<bool>(
        valueListenable: isCreatingNotifier,
        builder: (context, isCreating, _) {
          return BaseGlassDialog(
            title: l10n?.addNewCategory ?? 'New Category',
            maxWidth: 400,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   GhostTextField(
                    controller: controller,
                    autofocus: true,
                    labelText: l10n?.categoryName,
                    hintText: l10n?.enterCategoryName ?? 'e.g., Biology, History',
                    prefixIcon: Icons.create_new_folder_outlined,
                    enabled: !isCreating,
                    onSubmitted: (value) async {
                      if (value.trim().isNotEmpty && !isCreating) {
                        isCreatingNotifier.value = true;
                        await _createCategory(value.trim(), context);
                        // If checking mounted after await, the dialog likely popped, 
                        // so we might not simple 'set' isCreating back to false.
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isCreating ? null : () => Navigator.of(context).pop(),
                        child: Text(l10n?.cancel ?? 'Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isCreating ? null : () async {
                          if (controller.text.trim().isNotEmpty) {
                            isCreatingNotifier.value = true;
                            await _createCategory(controller.text.trim(), context);
                          }
                        },
                        child: isCreating
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(l10n?.create ?? 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
    isCreatingNotifier.dispose();

    if (result != null) {
      widget.onChanged(result.id);
    }
  }

  Future<void> _createCategory(String name, BuildContext dialogContext) async {
    try {
      final newCategory = await _categoryService.createCategory(name);

      setState(() {
        _categories.add(newCategory);
      });

      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(newCategory);
      }
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('Failed to create category: $e'),
            backgroundColor: Colors.red,
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
    final theme = Theme.of(context);

    // Loading state
    if (_isLoading) {
      return _buildContainer(
        colorScheme: colorScheme,
        child: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading categories...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return _buildContainer(
        colorScheme: colorScheme,
        child: InkWell(
          onTap: _loadCategories,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to load',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
              Icon(Icons.refresh, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      );
    }

    // Normal state - clickable selector
    final selectedCategory = _selectedCategory;
    final hasSelection = selectedCategory != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.labelText ?? (l10n?.category ?? 'Category'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Simple dropdown button without nested containers
        MouseRegion(
          key: _buttonKey,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: widget.isEnabled ? _showCategorySelector : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 16,
                vertical: widget.compact ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: _isHovering || _isDropdownOpen
                    ? colorScheme.surfaceContainerHighest.withAlpha((255 * 0.8).round())
                    : colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Simple icon without extra container
                  Icon(
                    hasSelection ? Icons.folder_rounded : Icons.folder_open_rounded,
                    size: widget.compact ? 18 : 20,
                    color: hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: widget.compact ? 10 : 12),
                  Expanded(
                    child: Text(
                      hasSelection
                          ? selectedCategory.name
                          : (widget.hintText ?? l10n?.selectCategory ?? 'Choose category'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: widget.compact ? 13 : 14,
                        color: hasSelection
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: hasSelection ? FontWeight.w500 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isDropdownOpen ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: widget.compact ? 18 : 20,
                      color: _isHovering || _isDropdownOpen
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContainer({
    required ColorScheme colorScheme,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}


/// Bottom sheet for selecting categories - Mobile optimized with drag-to-dismiss
class _CategorySelectorSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<CategoryModel> onCategorySelected;
  final VoidCallback onAddNew;
  final VoidCallback onRefresh;

  const _CategorySelectorSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onAddNew,
    required this.onRefresh,
  });

  @override
  State<_CategorySelectorSheet> createState() => _CategorySelectorSheetState();
}

class _CategorySelectorSheetState extends State<_CategorySelectorSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final systemCategories = widget.categories.where((c) => c.isSystem).toList();
    final userCategories = widget.categories.where((c) => !c.isSystem).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.75,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(isDark ? 0.65 : 0.75),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! > 500) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primaryContainer.withAlpha((255 * 0.7).round()),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.selectCategory ?? 'Select Category',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.categories.length} ${widget.categories.length == 1 ? 'category' : 'categories'} available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onRefresh,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Refresh',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              color: colorScheme.outlineVariant.withAlpha((255 * 0.3).round()),
              height: 1,
            ),

            // Categories list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // User categories first (more relevant)
                  if (userCategories.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      icon: Icons.person_rounded,
                      title: l10n?.myCategories ?? 'My Categories',
                      count: userCategories.length,
                    ),
                    ...userCategories.map((cat) => _buildCategoryTile(
                      context,
                      category: cat,
                      isSelected: cat.id == widget.selectedCategoryId,
                    )),
                    const SizedBox(height: 8),
                  ],

                  // System categories
                  if (systemCategories.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      icon: Icons.public_rounded,
                      title: l10n?.systemCategories ?? 'System Categories',
                      count: systemCategories.length,
                    ),
                    ...systemCategories.map((cat) => _buildCategoryTile(
                      context,
                      category: cat,
                      isSelected: cat.id == widget.selectedCategoryId,
                    )),
                  ],

                  // Empty state
                  if (widget.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_off_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No categories yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your first category below',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Add new button - Prominent at bottom
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withAlpha((255 * 0.3).round()),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onAddNew,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(l10n?.addNewCategory ?? 'Add New Category'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha((255 * 0.5).round()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required CategoryModel category,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onCategorySelected(category),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withAlpha((255 * 0.6).round())
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withAlpha((255 * 0.4).round())
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withAlpha((255 * 0.15).round())
                        : (category.isSystem
                            ? colorScheme.secondaryContainer.withAlpha((255 * 0.5).round())
                            : colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.isSystem
                        ? Icons.folder_special_rounded
                        : Icons.folder_rounded,
                    size: 20,
                    color: isSelected
                        ? colorScheme.primary
                        : (category.isSystem
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (category.isSystem)
                        Text(
                          'System default',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Container(
                          key: const ValueKey('selected'),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact version of CategoryDropdown for inline use
class CategoryChipSelector extends StatefulWidget {
  final List<String> selectedCategoryIds;
  final ValueChanged<List<String>> onChanged;
  final bool isMultiSelect;

  const CategoryChipSelector({
    super.key,
    required this.selectedCategoryIds,
    required this.onChanged,
    this.isMultiSelect = true,
  });

  @override
  State<CategoryChipSelector> createState() => _CategoryChipSelectorState();
}

class _CategoryChipSelectorState extends State<CategoryChipSelector> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) {
        final isSelected = widget.selectedCategoryIds.contains(category.id);
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.isSystem ? Icons.lock_outline : Icons.folder_outlined,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(category.name),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            final newSelection = List<String>.from(widget.selectedCategoryIds);
            if (widget.isMultiSelect) {
              if (selected) {
                newSelection.add(category.id);
              } else {
                newSelection.remove(category.id);
              }
            } else {
              newSelection.clear();
              if (selected) {
                newSelection.add(category.id);
              }
            }
            widget.onChanged(newSelection);
          },
          selectedColor: colorScheme.primaryContainer,
          checkmarkColor: colorScheme.onPrimaryContainer,
        );
      }).toList(),
    );
  }
}

