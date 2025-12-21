import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/conversation_provider.dart';

/// Chat screen - displays chat messages and input
/// Supports deep linking via [initialConversationId]
class ChatScreen extends StatefulWidget {
  /// Optional conversation ID for deep linking
  /// When provided, automatically selects this conversation on mount
  final int? initialConversationId;

  const ChatScreen({
    super.key,
    this.initialConversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _areStepsExpanded = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
      _scrollToBottom();
    });
  }

  void _initializeConversation() {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final provider = context.read<ConversationProvider>();

    // If we have an initial conversation ID from deep link, select it
    if (widget.initialConversationId != null) {
      provider.setCurrentConversation(widget.initialConversationId);
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle navigation to different conversation
    if (widget.initialConversationId != oldWidget.initialConversationId &&
        widget.initialConversationId != null) {
      context.read<ConversationProvider>().setCurrentConversation(
        widget.initialConversationId,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(ConversationProvider provider) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    provider.sendMessage(text);

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final hasConversation = provider.currentConversationId != null;

        // Scroll to bottom when messages change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.messages.isNotEmpty || provider.isStreaming) {
            _scrollToBottom();
          }
        });

        if (!hasConversation) {
          return _buildNoConversationState(context, l10n, colorScheme, provider);
        }

        return Column(
          children: [
            // Messages list
            Expanded(
              child: provider.isLoadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessagesList(context, provider, colorScheme),
            ),

            // Input area
            _buildInputArea(context, provider, l10n, colorScheme),
          ],
        );
      },
    );
  }

  Widget _buildNoConversationState(
    BuildContext context,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
    ConversationProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.selectConversation ?? 'Select a conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.orCreateNew ?? 'or create a new one from the sidebar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await provider.createConversation();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n?.new_conversation ?? 'New Conversation'),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildMessagesList(BuildContext context, ConversationProvider provider, ColorScheme colorScheme) {
  final allMessages = [...provider.messages];

  // Dodaj streamowaną wiadomość bota jeśli jest streaming
  if (provider.isStreaming) {
    // Dodaj wiadomość nawet jeśli tekst jest pusty - żeby panel kroków się wyświetlił
    allMessages.add(
      Message(
        role: 'bot',
        content: provider.streamingText,
        timestamp: null,
      ),
    );
  }

  // Jeśli nie ma żadnych wiadomości, pokaż empty state
  if (allMessages.isEmpty) {
    return _buildEmptyChat(context, colorScheme);
  }

  return ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: allMessages.length,
    itemBuilder: (context, index) {
      final message = allMessages[index];
      final isLastMessage = index == allMessages.length - 1;
      final isBot = message.role == 'bot';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // JEŚLI to jest ostatnia wiadomość bota i są kroki, wyświetl panel kroków NAD nią
          if (isBot && isLastMessage && provider.currentSteps.isNotEmpty)
            _StepsPanel(
              steps: List.from(provider.currentSteps), // Kopia listy dla bezpieczeństwa
              isExpanded: _areStepsExpanded,
              completedCount: provider.currentSteps.where((s) => s.status == 'complete').length,
              onToggle: () => setState(() => _areStepsExpanded = !_areStepsExpanded),
            ),

          // Nie wyświetlaj pustej bańki wiadomości podczas streamingu
          if (!(isBot && provider.isStreaming && message.content.isEmpty))
            _MessageBubble(
              message: message,
              isUser: message.role == 'user',
              isStreaming: provider.isStreaming && isLastMessage && isBot,
              colorScheme: colorScheme,
            ),
        ],
      );
    },
  );
}
  Widget _buildEmptyChat(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.startChatting ?? 'Start chatting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.askAnything ?? 'Ask me anything!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotAnimation(color: colorScheme.primary, delay: 0),
                const SizedBox(width: 4),
                _DotAnimation(color: colorScheme.primary, delay: 150),
                const SizedBox(width: 4),
                _DotAnimation(color: colorScheme.primary, delay: 300),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    ConversationProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tools button row
              if (provider.selectedTools.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: provider.selectedTools.map((tool) {
                      return Chip(
                        label: Text(tool, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => provider.toggleTool(tool),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),

              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Tools button
                  IconButton(
                    icon: Badge(
                      isLabelVisible: provider.selectedTools.isNotEmpty,
                      label: Text('${provider.selectedTools.length}'),
                      child: const Icon(Icons.build_outlined),
                    ),
                    onPressed: () => _showToolsDialog(context, provider, l10n),
                    tooltip: l10n?.tools ?? 'Tools',
                  ),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _sendMessage(provider),
                        decoration: InputDecoration(
                          hintText: l10n?.type_message ?? 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  IconButton.filled(
                    icon: provider.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    onPressed: provider.isSending
                        ? null
                        : () => _sendMessage(provider),
                  ),
                ],
              ),

              // Error message
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    provider.error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToolsDialog(
    BuildContext context,
    ConversationProvider provider,
    AppLocalizations? l10n,
  ) {
    final availableTools = [
      'Wiedza z plików',
      'Generowanie fiszek',
      'Generowanie egzaminu',
      'Wyszukaj w internecie',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.selectTools ?? 'Select Tools'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: availableTools.map((tool) {
                final isSelected = provider.selectedTools.contains(tool);
                return CheckboxListTile(
                  title: Text(tool),
                  value: isSelected,
                  onChanged: (value) {
                    provider.toggleTool(tool);
                    setDialogState(() {});
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearTools();
              Navigator.of(context).pop();
            },
            child: Text(l10n?.clearAll ?? 'Clear All'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.done ?? 'Done'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  final bool isStreaming;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.isStreaming,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content + (isStreaming ? '▊' : ''),
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isUser
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        height: 1.4,
                      ),
                      code: TextStyle(
                        backgroundColor: isUser
                            ? colorScheme.onPrimary.withOpacity(0.1)
                            : colorScheme.surfaceContainerHigh,
                        color: isUser
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.onPrimary.withOpacity(0.1)
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    selectable: true,
                  ),
                  if (message.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp!),
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? colorScheme.onPrimary.withOpacity(0.7)
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

class _DotAnimation extends StatefulWidget {
  final Color color;
  final int delay;

  const _DotAnimation({required this.color, required this.delay});

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.5 + 0.5 * _animation.value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _StepsPanel extends StatelessWidget {
  final List<ChatStep> steps;
  final bool isExpanded;
  final int completedCount;
  final VoidCallback onToggle;

  const _StepsPanel({
    required this.steps,
    required this.isExpanded,
    required this.completedCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allCompleted = steps.every((s) => s.status == 'complete');

    return Container(
      margin: const EdgeInsets.only(left: 40, right: 40, bottom: 12, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GÓRNY RZĄD – przycisk “x ukończonych kroków” + ikona rozwinięcia
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    allCompleted ? Icons.check_circle : Icons.auto_awesome,
                    size: 16,
                    color: allCompleted ? Colors.green : colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$completedCount ukończonych kroków',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // ROZWIJANA LISTA KROKÓW
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  final isLoading = step.status == 'loading';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: isLoading
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.content,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isLoading
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}