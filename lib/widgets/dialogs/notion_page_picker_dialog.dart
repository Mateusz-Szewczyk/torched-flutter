import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/notion_service.dart';
import '../../theme/dimens.dart';
import '../common/glass_components.dart';
import '../category_dropdown.dart';
import 'base_glass_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';

/// Dialog for browsing and selecting Notion pages to import
class NotionPagePickerDialog extends StatefulWidget {
  final String? initialCategoryId;

  const NotionPagePickerDialog({
    super.key,
    this.initialCategoryId,
  });

  static Future<NotionImportResult?> show(
    BuildContext context, {
    String? categoryId,
  }) {
    return BaseGlassDialog.show<NotionImportResult?>(
      context,
      builder: (context) => NotionPagePickerDialog(
        initialCategoryId: categoryId,
      ),
    );
  }

  @override
  State<NotionPagePickerDialog> createState() => _NotionPagePickerDialogState();
}

class _NotionPagePickerDialogState extends State<NotionPagePickerDialog> {
  final NotionService _notionService = NotionService();
  final TextEditingController _searchController = TextEditingController();
  
  List<NotionItem> _pages = [];
  List<NotionItem> _databases = [];
  bool _isLoading = true;
  bool _isImporting = false;
  String? _error;
  String? _selectedCategoryId;
  String? _selectedPageId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _loadContent();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final content = await _notionService.listContent();
      if (mounted) {
        setState(() {
          _pages = content.pages;
          _databases = content.databases;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load Notion content. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<NotionItem> get _filteredPages {
    if (_searchQuery.isEmpty) return _pages;
    return _pages.where((p) => p.title.toLowerCase().contains(_searchQuery)).toList();
  }

  List<NotionItem> get _filteredDatabases {
    if (_searchQuery.isEmpty) return _databases;
    return _databases.where((d) => d.title.toLowerCase().contains(_searchQuery)).toList();
  }

  Future<void> _importSelected() async {
    if (_selectedPageId == null || _selectedCategoryId == null) return;
    
    // Check limits before import
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final stats = subscriptionProvider.stats;
    final limits = stats?.limits ?? {};
    final usage = stats?.usage ?? {};
    
    final maxFiles = (limits['max_files'] as num?)?.toInt() ?? 5;
    // Backend returns 'files' for file count usage
    final currentFiles = (usage['files'] as num?)?.toInt() ?? 0;
    
    // Check for unlimited (-1) handled manually here or use provider helper
    if (maxFiles != -1 && currentFiles >= maxFiles) {
       setState(() => _error = 'File limit reached ($maxFiles files). Please upgrade your plan.');
       return;
    }
    
    HapticFeedback.mediumImpact();
    setState(() => _isImporting = true);
    
    try {
      final result = await _notionService.importPage(
        pageId: _selectedPageId!,
        categoryId: _selectedCategoryId!,
      );
      
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        if (result.success) {
          Navigator.of(context).pop(result);
        } else {
          setState(() {
            _error = result.message;
            _isImporting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Import failed: $e';
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return BaseGlassDialog(
      title: 'Import from Notion',
      maxWidth: 600,
      maxHeight: 700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: GhostTextField(
              controller: _searchController,
              hintText: 'Search pages...',
              prefixIcon: Icons.search,
            ),
          ),
          
          // Category selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: CategoryDropdown(
              selectedCategoryId: _selectedCategoryId,
              onChanged: (id) => setState(() => _selectedCategoryId = id),
              isEnabled: !_isImporting,
              hintText: 'Select category for import',
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Content area
          Expanded(
            child: _buildContent(cs),
          ),
          
          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: GlassTile(
                padding: const EdgeInsets.all(12),
                color: cs.error.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Import button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: (_selectedPageId != null && 
                           _selectedCategoryId != null && 
                           !_isImporting)
                    ? _importSelected
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusL),
                  ),
                ),
                child: _isImporting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Importing...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.download_outlined),
                          SizedBox(width: 8),
                          Text('Import Selected'),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final filteredPages = _filteredPages;
    final filteredDatabases = _filteredDatabases;
    
    if (filteredPages.isEmpty && filteredDatabases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, 
                 size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No pages found in your workspace'
                  : 'No pages match your search',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Pages section
        if (filteredPages.isNotEmpty) ...[
          _buildSectionHeader('Pages', filteredPages.length, cs),
          ...filteredPages.map((page) => _buildPageTile(page, cs)),
          const SizedBox(height: 16),
        ],
        
        // Databases section
        if (filteredDatabases.isNotEmpty) ...[
          _buildSectionHeader('Databases', filteredDatabases.length, cs),
          ...filteredDatabases.map((db) => _buildPageTile(db, cs)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTile(NotionItem item, ColorScheme cs) {
    final isSelected = _selectedPageId == item.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassTile(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPageId = item.id);
        },
        padding: const EdgeInsets.all(14),
        color: isSelected ? cs.primary.withValues(alpha: 0.12) : null,
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected 
                    ? cs.primary.withValues(alpha: 0.2)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: item.icon != null && item.icon!.length <= 2
                    ? Text(item.icon!, style: const TextStyle(fontSize: 18))
                    : Icon(
                        item.objectType == 'database' 
                            ? Icons.table_chart_outlined 
                            : Icons.description_outlined,
                        size: 18,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.lastEdited != null)
                    Text(
                      _formatDate(item.lastEdited!),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(Icons.check_circle, color: cs.primary, size: 22)
            else
              Icon(Icons.circle_outlined, 
                   color: cs.onSurfaceVariant.withValues(alpha: 0.3), 
                   size: 22),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays == 0) {
        return 'Edited today';
      } else if (diff.inDays == 1) {
        return 'Edited yesterday';
      } else if (diff.inDays < 7) {
        return 'Edited ${diff.inDays} days ago';
      } else {
        return 'Edited ${dt.day}.${dt.month}.${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
