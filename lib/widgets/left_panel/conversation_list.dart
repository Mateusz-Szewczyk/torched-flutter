import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/conversation_provider.dart';

/// Conversation list widget - equivalent to conversation-list.tsx
/// Shows list of conversations with edit/delete options
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
      context.read<ConversationProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationProvider = context.watch<ConversationProvider>();
    final conversations = conversationProvider.conversations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse and new conversation button
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                // New conversation button
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: () => _createNewConversation(context),
                  tooltip: 'New conversation',
                ),
              ],
            ),
          ),
        ),

        // Conversation list
        if (_isExpanded)
          conversationProvider.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : conversations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: conversations.length > 10 ? 10 : conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return _ConversationItem(
                          conversation: conversation,
                          onTap: () => widget.onConversationClick(conversation.id),
                          onEdit: () => _editConversation(context, conversation),
                          onDelete: () => _deleteConversation(context, conversation),
                        );
                      },
                    ),
      ],
    );
  }

  Future<void> _createNewConversation(BuildContext context) async {
    final provider = context.read<ConversationProvider>();
    final newConv = await provider.createConversation();
    if (newConv != null && mounted) {
      widget.onConversationClick(newConv.id);
    }
  }

  Future<void> _editConversation(BuildContext context, Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter conversation title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await context.read<ConversationProvider>().updateConversationTitle(
        conversation.id,
        result,
      );
    }

    controller.dispose();
  }

  Future<void> _deleteConversation(BuildContext context, Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete "${conversation.title ?? 'Untitled'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ConversationProvider>().deleteConversation(conversation.id);
    }
  }
}

/// Individual conversation item with menu
class _ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConversationItem({
    required this.conversation,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                conversation.title ?? 'Untitled',
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // More menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16),
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: 'More options',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

