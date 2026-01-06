import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/memory_service.dart';

/// Memories management widget for the Profile dialog
/// Provides a beautiful UI for viewing, adding, and deleting user memories
class MemoriesSection extends StatefulWidget {
  const MemoriesSection({super.key});

  @override
  State<MemoriesSection> createState() => _MemoriesSectionState();
}

class _MemoriesSectionState extends State<MemoriesSection> with SingleTickerProviderStateMixin {
  final MemoryService _memoryService = MemoryService();
  final TextEditingController _newMemoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Memory> _memories = [];
  MemoryStats? _stats;
  bool _isLoading = true;
  bool _isAddingMemory = false;
  bool _showAddForm = false;
  double _newMemoryImportance = 0.5;
  String? _error;
  String _searchQuery = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadMemories();
  }

  @override
  void dispose() {
    _newMemoryController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _memoryService.fetchMemories(),
        _memoryService.getStats(),
      ]);

      setState(() {
        _memories = futures[0] as List<Memory>;
        _stats = futures[1] as MemoryStats;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addMemory() async {
    final text = _newMemoryController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAddingMemory = true);

    try {
      final newMemory = await _memoryService.createMemory(
        text: text,
        importance: _newMemoryImportance,
      );

      setState(() {
        _memories.insert(0, newMemory);
        _newMemoryController.clear();
        _newMemoryImportance = 0.5;
        _showAddForm = false;
        _isAddingMemory = false;
      });

      // Refresh stats
      _memoryService.getStats().then((stats) {
        setState(() => _stats = stats);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Memory saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAddingMemory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add memory: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _deleteMemory(Memory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Delete Memory'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this memory?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                memory.text.length > 100
                    ? '${memory.text.substring(0, 100)}...'
                    : memory.text,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _memoryService.deleteMemory(memory.id);
        setState(() {
          _memories.removeWhere((m) => m.id == memory.id);
        });

        // Refresh stats
        _memoryService.getStats().then((stats) {
          setState(() => _stats = stats);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Memory deleted'),
                ],
              ),
              backgroundColor: Colors.grey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete memory: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Delete All Memories'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is irreversible!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('All your memories will be permanently deleted. Are you sure?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _memoryService.deleteAllMemories();
        setState(() {
          _memories.clear();
          _stats = MemoryStats(
            totalMemories: 0,
            averageImportance: 0,
            importanceDistribution: ImportanceDistribution(high: 0, medium: 0, low: 0),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.white),
                  SizedBox(width: 8),
                  Text('All memories deleted'),
                ],
              ),
              backgroundColor: Colors.grey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete memories: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  List<Memory> get _filteredMemories {
    if (_searchQuery.isEmpty) return _memories;
    return _memories
        .where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading memories...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading memories', style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadMemories,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          _buildHeader(colorScheme),

          const SizedBox(height: 16),

          // Stats cards
          if (_stats != null) _buildStatsCards(colorScheme),

          const SizedBox(height: 16),

          // Search and actions bar
          _buildActionsBar(colorScheme),

          const SizedBox(height: 12),

          // Add memory form
          if (_showAddForm) ...[
            _buildAddMemoryForm(colorScheme),
            const SizedBox(height: 16),
          ],

          // Memories list
          Expanded(
            child: _filteredMemories.isEmpty
                ? _buildEmptyState(colorScheme)
                : _buildMemoriesList(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.psychology,
            color: colorScheme.onPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Memory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'What I remember about you',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_memories.isNotEmpty)
          IconButton(
            onPressed: _deleteAllMemories,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Delete all memories',
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _buildStatsCards(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.memory,
            label: 'Total',
            value: _stats!.totalMemories.toString(),
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            label: 'High',
            value: _stats!.importanceDistribution.high.toString(),
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.horizontal_rule,
            label: 'Medium',
            value: _stats!.importanceDistribution.medium.toString(),
            color: Colors.orange.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_down,
            label: 'Low',
            value: _stats!.importanceDistribution.low.toString(),
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsBar(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search memories...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerLowest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => setState(() => _showAddForm = !_showAddForm),
          icon: Icon(_showAddForm ? Icons.close : Icons.add),
          label: Text(_showAddForm ? 'Cancel' : 'Add'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMemoryForm(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withAlpha(130),
            colorScheme.tertiaryContainer.withAlpha(80),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_comment, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'New Memory',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newMemoryController,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: 'What should I remember about you?\nE.g., "I prefer concise answers" or "I am learning Flutter"',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.priority_high,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Importance:',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              _ImportanceChip(
                label: 'Low',
                isSelected: _newMemoryImportance < 0.3,
                onTap: () => setState(() => _newMemoryImportance = 0.15),
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              _ImportanceChip(
                label: 'Medium',
                isSelected: _newMemoryImportance >= 0.3 && _newMemoryImportance < 0.7,
                onTap: () => setState(() => _newMemoryImportance = 0.5),
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              _ImportanceChip(
                label: 'High',
                isSelected: _newMemoryImportance >= 0.7,
                onTap: () => setState(() => _newMemoryImportance = 0.85),
                color: Colors.green,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isAddingMemory ? null : _addMemory,
                child: _isAddingMemory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Memory'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No memories yet' : 'No matching memories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add memories to help me personalize your experience'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showAddForm = true),
              icon: const Icon(Icons.add),
              label: const Text('Add your first memory'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoriesList(ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredMemories.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final memory = _filteredMemories[index];
        return _MemoryCard(
          memory: memory,
          onDelete: () => _deleteMemory(memory),
        );
      },
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Importance selection chip
class _ImportanceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ImportanceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : color.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

/// Memory card widget
class _MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color importanceColor;
    IconData importanceIcon;
    switch (memory.importanceLevel) {
      case ImportanceLevel.high:
        importanceColor = Colors.green.shade600;
        importanceIcon = Icons.arrow_upward;
        break;
      case ImportanceLevel.medium:
        importanceColor = Colors.orange.shade600;
        importanceIcon = Icons.remove;
        break;
      case ImportanceLevel.low:
        importanceColor = Colors.grey.shade600;
        importanceIcon = Icons.arrow_downward;
        break;
    }

    return Dismissible(
      key: Key(memory.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Memory?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: memory.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Memory copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        memory.text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.error.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Importance badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: importanceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: importanceColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(importanceIcon, size: 12, color: importanceColor),
                          const SizedBox(width: 4),
                          Text(
                            memory.importanceLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: importanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Created date
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(memory.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}

