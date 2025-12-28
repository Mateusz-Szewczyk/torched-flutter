import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
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

  bool _hasInitialized = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
      _scrollToBottom(animated: false, delayed: true);
    });
  }

  void _initializeConversation() {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final provider = context.read<ConversationProvider>();
    if (widget.initialConversationId != null) {
      provider.setCurrentConversation(widget.initialConversationId);
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != oldWidget.initialConversationId &&
        widget.initialConversationId != null) {
      _lastMessageCount = 0;
      context.read<ConversationProvider>().setCurrentConversation(
        widget.initialConversationId,
      );
      _scrollToBottom(animated: false, delayed: true);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true, bool delayed = false}) {
    void doScroll() {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (animated && maxExtent > 0) {
          _scrollController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else if (maxExtent > 0) {
          _scrollController.jumpTo(maxExtent);
        }
      }
    }

    if (delayed) {
      Future.delayed(const Duration(milliseconds: 100), doScroll);
      Future.delayed(const Duration(milliseconds: 300), doScroll);
    } else {
      doScroll();
    }
  }

  void _sendMessage(ConversationProvider provider) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    provider.sendMessage(text);
    _scrollToBottom(delayed: true);
  }

  void _showToolsBottomSheet(BuildContext context, ConversationProvider provider) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ToolsBottomSheet(
        provider: provider,
        l10n: l10n,
        colorScheme: colorScheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final hasConversation = provider.currentConversationId != null;
        final currentMessageCount = provider.messages.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentMessageCount > _lastMessageCount || provider.isStreaming) {
            _scrollToBottom();
            _lastMessageCount = currentMessageCount;
          } else if (currentMessageCount > 0 && _lastMessageCount == 0) {
            _scrollToBottom(animated: false, delayed: true);
            _lastMessageCount = currentMessageCount;
          }
        });

        if (!hasConversation) {
          _lastMessageCount = 0;
          return _buildNoConversationState(context, l10n, colorScheme, provider);
        }

        return Column(
          children: [
            Expanded(
              child: provider.isLoadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessagesList(context, provider, colorScheme),
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.selectConversation ?? 'Start a conversation',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.orCreateNew ?? 'Ask me anything about your studies',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async => await provider.createConversation(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n?.new_conversation ?? 'New Conversation'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, ConversationProvider provider, ColorScheme colorScheme) {
    final allMessages = [...provider.messages];
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (provider.isStreaming) {
      allMessages.add(
        Message(role: 'bot', content: provider.streamingText, timestamp: null),
      );
    }

    if (allMessages.isEmpty) {
      return _buildEmptyChat(context, colorScheme);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: 16,
      ),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[index];
        final isLastMessage = index == allMessages.length - 1;
        final isBot = message.role == 'bot';

        final parsedMetadata = message.parsedMetadata;
        final hasPersistedSteps = parsedMetadata?.steps?.isNotEmpty ?? false;
        final hasPersistedActions = parsedMetadata?.actions?.isNotEmpty ?? false;

        final bool hasLiveSteps = provider.currentSteps.isNotEmpty;
        final bool hasLiveActions = provider.generatedActions.isNotEmpty;

        final bool showLiveSteps = isBot && isLastMessage && hasLiveSteps;
        final bool showPersistedSteps = isBot && hasPersistedSteps && (!isLastMessage || !hasLiveSteps);

        final bool showLiveActions = isBot && isLastMessage && !provider.isStreaming && hasLiveActions;
        final bool showPersistedActions = isBot && hasPersistedActions && (!isLastMessage || !hasLiveActions);

        return Padding(
          padding: EdgeInsets.only(bottom: isLastMessage ? 8 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Steps panel (live or persisted)
              if (showLiveSteps)
                _MinimalStepsPanel(steps: List.from(provider.currentSteps))
              else if (showPersistedSteps)
                _MinimalPersistedStepsPanel(steps: parsedMetadata!.steps!),

              // Message bubble - skip empty streaming messages
              if (!(isBot && provider.isStreaming && message.content.isEmpty))
                _MinimalMessageBubble(
                  message: message,
                  isUser: message.role == 'user',
                  isStreaming: provider.isStreaming && isLastMessage && isBot,
                  colorScheme: colorScheme,
                  isMobile: isMobile,
                ),

              // Actions (live or persisted)
              if (showLiveActions)
                _MinimalActionsWidget(
                  actions: provider.generatedActions,
                  isMobile: isMobile,
                  onNavigate: (action) {
                    provider.clearGeneratedActions();
                    context.go(action.routePath);
                  },
                )
              else if (showPersistedActions)
                _MinimalPersistedActionsWidget(
                  actions: parsedMetadata!.actions!,
                  isMobile: isMobile,
                  onNavigate: (action) {
                    context.go(action.type == 'flashcards' ? '/flashcards' : '/tests');
                  },
                ),
            ],
          ),
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
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.startChatting ?? 'Start chatting',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.askAnything ?? 'Ask me anything!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final edgePadding = isMobile ? 16.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(50),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: edgePadding,
            right: edgePadding,
            top: 12,
            bottom: edgePadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected tools chips - horizontal scroll
              if (provider.selectedTools.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.selectedTools.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final tool = provider.selectedTools[index];
                      return _ToolChip(
                        label: _getToolShortName(tool),
                        onRemove: () => provider.toggleTool(tool),
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ),

              // Main input row - pill style
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Tools button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _ToolsButton(
                        hasTools: provider.selectedTools.isNotEmpty,
                        toolCount: provider.selectedTools.length,
                        onPressed: () => _showToolsBottomSheet(context, provider),
                        colorScheme: colorScheme,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Text input
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _inputFocusNode,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n?.type_message ?? 'Ask anything...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withAlpha(130),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SendButton(
                        isSending: provider.isSending,
                        onPressed: () => _sendMessage(provider),
                        colorScheme: colorScheme,
                      ),
                    ),
                  ],
                ),
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

  String _getToolShortName(String tool) {
    switch (tool) {
      case 'Wiedza z plików':
        return 'Files';
      case 'Generowanie fiszek':
        return 'Flashcards';
      case 'Generowanie egzaminu':
        return 'Exam';
      case 'Wyszukaj w internecie':
        return 'Web';
      default:
        return tool;
    }
  }
}

// ============================================================================
// MINIMAL COMPONENTS
// ============================================================================

/// Clean tools button - simple plus icon with badge
class _ToolsButton extends StatelessWidget {
  final bool hasTools;
  final int toolCount;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _ToolsButton({
    required this.hasTools,
    required this.toolCount,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 28,
              color: hasTools
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            // Badge
            if (hasTools)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$toolCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Clean send button - circular with white arrow
class _SendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _SendButton({
    required this.isSending,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSending ? colorScheme.surfaceContainerHigh : colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isSending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  size: 22,
                  color: colorScheme.onPrimary,
                ),
        ),
      ),
    );
  }
}

/// Small tool chip - clean design
class _ToolChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final ColorScheme colorScheme;

  const _ToolChip({
    required this.label,
    required this.onRemove,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: colorScheme.onPrimaryContainer.withAlpha(180),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal message bubble - Perplexity style
class _MinimalMessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  final bool isStreaming;
  final ColorScheme colorScheme;
  final bool isMobile;

  const _MinimalMessageBubble({
    required this.message,
    required this.isUser,
    required this.isStreaming,
    required this.colorScheme,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot avatar
          if (!isUser) ...[
            Container(
              width: isMobile ? 28 : 32,
              height: isMobile ? 28 : 32,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: isMobile ? 16 : 18,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
          ],

          // Message content
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile
                    ? MediaQuery.of(context).size.width * 0.85
                    : MediaQuery.of(context).size.width * 0.7,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
              ),
              child: MarkdownBody(
                data: message.content + (isStreaming ? ' ▌' : ''),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontSize: isMobile ? 14 : 15,
                    height: 1.5,
                  ),
                  code: TextStyle(
                    backgroundColor: isUser
                        ? colorScheme.onPrimary.withOpacity(0.15)
                        : colorScheme.surfaceContainerHigh,
                    color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontSize: 13,
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
            ),
          ),

          // User avatar
          if (isUser) ...[
            SizedBox(width: isMobile ? 8 : 12),
            Container(
              width: isMobile ? 28 : 32,
              height: isMobile ? 28 : 32,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_rounded,
                size: isMobile ? 16 : 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minimal steps panel - clean, collapsed by default
class _MinimalStepsPanel extends StatefulWidget {
  final List<ChatStep> steps;

  const _MinimalStepsPanel({required this.steps});

  @override
  State<_MinimalStepsPanel> createState() => _MinimalStepsPanelState();
}

class _MinimalStepsPanelState extends State<_MinimalStepsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedCount = widget.steps.where((s) => s.status == 'complete').length;
    final isLoading = widget.steps.any((s) => s.status == 'loading');
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 36 : 44,
        right: isMobile ? 8 : 24,
        bottom: 8,
      ),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLoading
                          ? 'Thinking...'
                          : '$completedCount steps completed',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded steps list
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: widget.steps.map((step) => _StepItem(
                      step: step,
                      colorScheme: colorScheme,
                    )).toList(),
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final ChatStep step;
  final ColorScheme colorScheme;

  const _StepItem({required this.step, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isLoading = step.status == 'loading';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: isLoading
                ? CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colorScheme.primary,
                  )
                : Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.green.shade600,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.content,
              style: TextStyle(
                fontSize: 12,
                color: isLoading
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal persisted steps panel
class _MinimalPersistedStepsPanel extends StatefulWidget {
  final List<MessageStep> steps;

  const _MinimalPersistedStepsPanel({required this.steps});

  @override
  State<_MinimalPersistedStepsPanel> createState() => _MinimalPersistedStepsPanelState();
}

class _MinimalPersistedStepsPanelState extends State<_MinimalPersistedStepsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedCount = widget.steps.length;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 36 : 44,
        right: isMobile ? 8 : 24,
        bottom: 8,
      ),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Colors.green.shade600.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$completedCount steps',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: widget.steps.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.green.shade600.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal actions widget - clean cards
class _MinimalActionsWidget extends StatelessWidget {
  final List<GeneratedAction> actions;
  final bool isMobile;
  final void Function(GeneratedAction action) onNavigate;

  const _MinimalActionsWidget({
    required this.actions,
    required this.isMobile,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 36 : 44,
        right: isMobile ? 8 : 24,
        top: 4,
        bottom: 8,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) => _ActionCard(
          label: action.label,
          onTap: () => onNavigate(action),
          colorScheme: colorScheme,
          isMobile: isMobile,
        )).toList(),
      ),
    );
  }
}

/// Minimal persisted actions widget
class _MinimalPersistedActionsWidget extends StatelessWidget {
  final List<MessageAction> actions;
  final bool isMobile;
  final Function(MessageAction) onNavigate;

  const _MinimalPersistedActionsWidget({
    required this.actions,
    required this.isMobile,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 36 : 44,
        right: isMobile ? 8 : 24,
        top: 4,
        bottom: 8,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          final icon = action.type == 'flashcards' ? '📚' : '📝';
          final itemLabel = action.type == 'flashcards' ? 'flashcards' : 'questions';

          return _ActionCard(
            label: '$icon ${action.name} (${action.count} $itemLabel)',
            onTap: () => onNavigate(action),
            colorScheme: colorScheme,
            isMobile: isMobile,
          );
        }).toList(),
      ),
    );
  }
}

/// Clean action card
class _ActionCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isMobile;

  const _ActionCard({
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TOOLS BOTTOM SHEET
// ============================================================================

class _ToolsBottomSheet extends StatefulWidget {
  final ConversationProvider provider;
  final AppLocalizations? l10n;
  final ColorScheme colorScheme;

  const _ToolsBottomSheet({
    required this.provider,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  State<_ToolsBottomSheet> createState() => _ToolsBottomSheetState();
}

class _ToolsBottomSheetState extends State<_ToolsBottomSheet> {
  final List<_ToolOption> _tools = [
    _ToolOption(
      id: 'Wiedza z plików',
      name: 'Knowledge from files',
      description: 'Search your uploaded documents',
      icon: Icons.folder_rounded,
    ),
    _ToolOption(
      id: 'Generowanie fiszek',
      name: 'Generate flashcards',
      description: 'Create flashcards from your materials',
      icon: Icons.style_rounded,
    ),
    _ToolOption(
      id: 'Generowanie egzaminu',
      name: 'Generate exam',
      description: 'Create practice exams',
      icon: Icons.quiz_rounded,
    ),
    _ToolOption(
      id: 'Wyszukaj w internecie',
      name: 'Web search',
      description: 'Search the internet for information',
      icon: Icons.language_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.build_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.l10n?.selectTools ?? 'Select Tools',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.provider.selectedTools.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      widget.provider.clearTools();
                      setState(() {});
                    },
                    child: Text(
                      widget.l10n?.clearAll ?? 'Clear',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Divider(color: colorScheme.outlineVariant.withOpacity(0.5), height: 1),

          // Tools list
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: _tools.map((tool) {
                final isSelected = widget.provider.selectedTools.contains(tool.id);
                return _ToolListItem(
                  tool: tool,
                  isSelected: isSelected,
                  colorScheme: colorScheme,
                  onTap: () {
                    widget.provider.toggleTool(tool.id);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          ),

          // Bottom button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPadding),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.l10n?.done ?? 'Done',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const _ToolOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _ToolListItem extends StatelessWidget {
  final _ToolOption tool;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _ToolListItem({
    required this.tool,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tool.icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: isSelected ? 0 : 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colorScheme.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
