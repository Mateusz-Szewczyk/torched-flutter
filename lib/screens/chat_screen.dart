import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'dart:math'; // Import for min function
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/conversation_provider.dart';

// Configuration constants for the "Reading Column" layout
const double kMaxContentWidth = 800.0;
const double kDesktopBreakpoint = 600.0;

/// Chat screen - displays chat messages and input
/// Supports deep linking via [initialConversationId]
class ChatScreen extends StatefulWidget {
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
            curve: Curves.easeOutCubic,
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

  void _showToolsBottomSheet(
      BuildContext context, ConversationProvider provider) {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= kDesktopBreakpoint;

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

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Stack(
            children: [
              // Main Chat Area
              Positioned.fill(
                child: !hasConversation
                    ? _buildNoConversationState(
                        context, l10n, colorScheme, provider)
                    : provider.isLoadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMessagesList(
                            context, provider, colorScheme, isDesktop),
              ),

              // Input Area (Positioned absolute for the floating effect)
              if (hasConversation)
                _buildInputArea(
                    context, provider, l10n, colorScheme, isDesktop),
            ],
          ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n?.selectConversation ?? 'Start a conversation',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.orCreateNew ?? 'Ask me anything about your studies',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () async {
                final conv = await provider.createConversation();
                if (conv != null && context.mounted) {
                  provider.setCurrentConversation(conv.id);
                  context.go('/chat/${conv.id}');
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n?.new_conversation ?? 'New Conversation'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, ConversationProvider provider,
      ColorScheme colorScheme, bool isDesktop) {
    final allMessages = [...provider.messages];
    final isMobile = !isDesktop;
    final screenWidth = MediaQuery.of(context).size.width;

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
      // Add significant bottom padding so the last message isn't hidden behind the input
      padding: EdgeInsets.only(
        top: 24,
        bottom: isDesktop ? 180 : 160,
      ),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[index];
        final isLastMessage = index == allMessages.length - 1;
        final isBot = message.role == 'bot';

        final parsedMetadata = message.parsedMetadata;
        final hasPersistedSteps = parsedMetadata?.steps?.isNotEmpty ?? false;
        final hasPersistedActions =
            parsedMetadata?.actions?.isNotEmpty ?? false;

        final bool hasLiveSteps = provider.currentSteps.isNotEmpty;
        final bool hasLiveActions = provider.generatedActions.isNotEmpty;

        final bool showLiveSteps = isBot && isLastMessage && hasLiveSteps;
        final bool showPersistedSteps =
            isBot && hasPersistedSteps && (!isLastMessage || !hasLiveSteps);

        final bool showLiveActions = isBot &&
            isLastMessage &&
            !provider.isStreaming &&
            hasLiveActions;
        final bool showPersistedActions = isBot &&
            hasPersistedActions &&
            (!isLastMessage || !hasLiveActions);

        // UI LOGIC FOR DESKTOP WIDTH
        return Center(
          child: Container(
            width: isDesktop ? screenWidth * 0.95 : null,
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            padding: const EdgeInsets.symmetric(
                horizontal: 16), // Ensure padding even on mobile
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Steps panel
                if (showLiveSteps)
                  _MinimalStepsPanel(steps: List.from(provider.currentSteps))
                else if (showPersistedSteps)
                  _MinimalPersistedStepsPanel(steps: parsedMetadata!.steps!),

                // Message bubble
                if (!(isBot &&
                    provider.isStreaming &&
                    message.content.isEmpty))
                  _MinimalMessageBubble(
                    message: message,
                    isUser: message.role == 'user',
                    isStreaming:
                        provider.isStreaming && isLastMessage && isBot,
                    colorScheme: colorScheme,
                    isMobile: isMobile,
                  ),

                // Actions
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
                      context.go(action.type == 'flashcards'
                          ? '/flashcards'
                          : '/tests');
                    },
                  ),
              ],
            ),
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
            size: 48,
            color: colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.startChatting ?? 'Start chatting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
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
    bool isDesktop,
  ) {
    if (isDesktop) {
      return _buildDesktopInput(context, provider, l10n, colorScheme);
    }
    return _buildMobileInput(context, provider, l10n, colorScheme);
  }

  // ==========================================================================
  // MOBILE INPUT (Docked at bottom)
  // ==========================================================================
  Widget _buildMobileInput(
    BuildContext context,
    ConversationProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.selectedTools.isNotEmpty)
                  _buildToolsChipsList(provider, colorScheme),

                // The main Pill
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ToolsButton(
                          hasTools: provider.selectedTools.isNotEmpty,
                          toolCount: provider.selectedTools.length,
                          onPressed: () =>
                              _showToolsBottomSheet(context, provider),
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                            l10n, colorScheme, provider, false),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SendButton(
                          isSending: provider.isSending,
                          onPressed: () => _sendMessage(provider),
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.error != null)
                  _buildErrorText(provider, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DESKTOP INPUT (Floating Island)
  // ==========================================================================
  Widget _buildDesktopInput(
    BuildContext context,
    ConversationProvider provider,
    AppLocalizations? l10n,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        margin: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
        // The main Pill
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withOpacity(0.4), // Slightly distinct from bg
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.selectedTools.isNotEmpty)
              _buildToolsChipsList(provider, colorScheme),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _ToolsButton(
                    hasTools: provider.selectedTools.isNotEmpty,
                    toolCount: provider.selectedTools.length,
                    onPressed: () => _showToolsBottomSheet(context, provider),
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      l10n, colorScheme, provider, true),
                ),
                const SizedBox(width: 12),
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
            if (provider.error != null) _buildErrorText(provider, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsChipsList(
      ConversationProvider provider, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: provider.selectedTools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tool = provider.selectedTools[index];
          return _ToolChip(
            label: _getToolShortName(tool),
            onRemove: () => provider.toggleTool(tool),
            colorScheme: colorScheme,
          );
        },
      ),
    );
  }

  /// Builds the text field.
  ///
  /// [isDesktop] enables "Enter to send" logic.
  Widget _buildTextField(
    AppLocalizations? l10n,
    ColorScheme colorScheme,
    ConversationProvider provider,
    bool isDesktop,
  ) {
    final textField = TextField(
      controller: _messageController,
      focusNode: _inputFocusNode,
      maxLines: null,
      textInputAction: TextInputAction.newline,
      style: TextStyle(
        fontSize: 16,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: false, // Ensure transparent background so it blends with the pill
        hintText: l10n?.type_message ?? 'Message...',
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.85),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: 14,
        ),
      ),
    );

    // If Desktop, wrap with shortcut listener to handle Enter key
    if (isDesktop) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!HardwareKeyboard.instance.isShiftPressed) {
               _sendMessage(provider);
            }
          },
        },
        child: textField,
      );
    }

    return textField;
  }

  Widget _buildErrorText(
      ConversationProvider provider, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Text(
        provider.error!,
        style: TextStyle(color: colorScheme.error, fontSize: 12),
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
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: hasTools
            ? colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        padding: EdgeInsets.zero,
        fixedSize: const Size(36, 36),
      ),
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 26,
            color: hasTools
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withOpacity(0.8),
          ),
          if (hasTools)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSending
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isSending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: colorScheme.onPrimary,
                ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final bool isUser;
  final ColorScheme colorScheme;

  const _ChatAvatar({required this.isUser, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isUser ? Colors.transparent : colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
              child: isUser
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/images/favicon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
    );
  }
}

/// Minimal message bubble
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
      padding: EdgeInsets.only(
        top: 16,
        bottom: 8,
        left: isUser ? 40 : 0,
        right: isUser ? 0 : 20,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot Avatar (Left)
          if (!isUser) ...[
            _ChatAvatar(isUser: false, colorScheme: colorScheme),
            const SizedBox(width: 12),
          ],

          // Message Content
          Flexible(
            child: Container(
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(isUser ? 20 : 0),
              ),
              child: MarkdownBody(
                data: message.content + (isStreaming ? ' ▌' : ''),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: isMobile ? 15 : 16,
                    height: 1.6,
                  ),
                  h1: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                  h2: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                  h3: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  code: TextStyle(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2)),
                  ),
                ),
                selectable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalStepsPanel extends StatefulWidget {
  final List<ChatStep> steps;

  const _MinimalStepsPanel({required this.steps});

  @override
  State<_MinimalStepsPanel> createState() => _MinimalStepsPanelState();
}

class _MinimalStepsPanelState extends State<_MinimalStepsPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < kDesktopBreakpoint;

    // Determine if we are still processing
    final bool isThinking =
        widget.steps.any((step) => step.status == 'loading');

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 44 : 44, // Align with text start
        right: 16,
        bottom: 8,
        top: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isThinking)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isThinking ? 'Thinking...' : 'Thought Process',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8, left: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.steps
                    .map((step) => _StepItem(
                          step: step,
                          colorScheme: colorScheme,
                        ))
                    .toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
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
    final isComplete = step.status == 'complete';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isLoading
                  ? Icons.circle_outlined
                  : (isComplete
                      ? Icons.check_circle_outline_rounded
                      : Icons.circle_outlined),
              size: 14,
              color: isLoading
                  ? colorScheme.primary
                  : (isComplete
                      ? Colors.green
                      : colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.content,
              style: TextStyle(
                fontSize: 13,
                color: isLoading
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalPersistedStepsPanel extends StatefulWidget {
  final List<MessageStep> steps;

  const _MinimalPersistedStepsPanel({required this.steps});

  @override
  State<_MinimalPersistedStepsPanel> createState() =>
      _MinimalPersistedStepsPanelState();
}

class _MinimalPersistedStepsPanelState
    extends State<_MinimalPersistedStepsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < kDesktopBreakpoint;

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 44 : 44,
        right: 16,
        bottom: 8,
        top: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thought Process',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 6, left: 8),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      step.content,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

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
        left: isMobile ? 44 : 44,
        right: 16,
        top: 8,
        bottom: 16,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map((action) => _ActionCard(
                  label: action.label,
                  onTap: () => onNavigate(action),
                  colorScheme: colorScheme,
                  isMobile: isMobile,
                ))
            .toList(),
      ),
    );
  }
}

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
        left: isMobile ? 44 : 44,
        right: 16,
        top: 8,
        bottom: 16,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          final icon = action.type == 'flashcards' ? '📚' : '📝';
          final itemLabel =
              action.type == 'flashcards' ? 'flashcards' : 'questions';

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
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
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
    const _ToolOption(
      id: 'Wyszukaj w internecie',
      name: 'Web search',
      description: 'Search the internet for information',
      icon: Icons.public,
    ),
    const _ToolOption(
      id: 'Wiedza z plików',
      name: 'Knowledge from files',
      description: 'Search your uploaded documents',
      icon: Icons.folder_open_rounded,
    ),
    const _ToolOption(
      id: 'Generowanie fiszek',
      name: 'Generate flashcards',
      description: 'Create flashcards from your materials',
      icon: Icons.style_outlined,
    ),
    const _ToolOption(
      id: 'Generowanie egzaminu',
      name: 'Generate exam',
      description: 'Create practice exams',
      icon: Icons.assignment_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.l10n?.selectTools ?? 'Available Tools',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
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
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tools list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _tools.map((tool) {
                final isSelected =
                    widget.provider.selectedTools.contains(tool.id);
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

          const SizedBox(height: 16),

          // Bottom button
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPadding),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: Text(
                  widget.l10n?.done ?? 'Done',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withOpacity(0.4)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tool.icon,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}