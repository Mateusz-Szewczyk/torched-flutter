import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/conversation_provider.dart';

/// Conversation list widget - equivalent to conversation-list.tsx
/// Shows list of conversations with swipe actions and pull-to-refresh
class ConversationList extends StatefulWidget {
  final Function(int) onConversationClick;

  const ConversationList({
    super.key,
    required this.onConversationClick,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Load conversations when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversationProvider = context.watch<ConversationProvider>();
    final conversations = conversationProvider.conversations;
    final currentId = conversationProvider.currentConversationId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse and new conversation button
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // New conversation button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _createNewConversation(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Conversation list with animations
        AnimatedCrossFade(
          firstChild: _buildConversationList(
            context,
            conversationProvider,
            conversations,
            currentId,
            colorScheme,
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    ConversationProvider provider,
    List<Conversation> conversations,
    int? currentId,
    ColorScheme colorScheme,
  ) {
    if (provider.isLoadingConversations && conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 32,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _createNewConversation(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Start chatting'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: conversations.length > 15 ? 15 : conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isSelected = conversation.id == currentId;

        return _SwipeableConversationItem(
          key: ValueKey(conversation.id),
          conversation: conversation,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onConversationClick(conversation.id);
          },
          onEdit: () => _editConversation(context, conversation),
          onDelete: () => _deleteConversation(context, conversation),
        );
      },
    );
  }

  Future<void> _createNewConversation(BuildContext context) async {
    HapticFeedback.lightImpact();
    final provider = context.read<ConversationProvider>();
    final newConv = await provider.createConversation();
    if (newConv != null && mounted) {
      widget.onConversationClick(newConv.id);
    }
  }

  Future<void> _editConversation(BuildContext context, Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter conversation title',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<ConversationProvider>().updateConversationTitle(
        conversation.id,
        result,
      );
    }

    controller.dispose();
  }

  Future<void> _deleteConversation(BuildContext context, Conversation conversation) async {
    HapticFeedback.mediumImpact();
    await context.read<ConversationProvider>().deleteConversation(conversation.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${conversation.title}"'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Swipeable conversation item using native Dismissible
class _SwipeableConversationItem extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SwipeableConversationItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Dismissible(
        key: ValueKey(conversation.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline,
            color: colorScheme.onError,
            size: 20,
          ),
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          return true;
        },
        onDismissed: (direction) => onDelete(),
        child: Material(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showContextMenu(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    size: 16,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conversation.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Subtle swipe hint
                  Icon(
                    Icons.chevron_left,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

