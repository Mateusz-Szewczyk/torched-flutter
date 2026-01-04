import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

// Ensure these imports match your actual file structure
import '../providers/conversation_provider.dart' show ChatStep, GeneratedAction;
import '../models/models.dart'; // Should contain WorkspaceMessage, MessageStep, MessageAction, MessageMetadata
import '../services/workspace_service.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/document_reader_widget.dart';
import '../widgets/workspace_form_dialog.dart';

// Configuration constants
const double kMaxContentWidth = 800.0;
const double kDesktopBreakpoint = 900.0;

/// Main Workspace Screen with responsive three-pane layout
class WorkspaceScreen extends StatefulWidget {
  final String workspaceId;

  const WorkspaceScreen({
    super.key,
    required this.workspaceId,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final WorkspaceService _workspaceService = WorkspaceService();
  final ChatService _chatService = ChatService();

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  late TabController _tabController;

  // Workspace Data
  WorkspaceModel? _workspace;
  List<WorkspaceDocumentBrief> _documents = [];
  String? _selectedDocumentId;
  bool _isLoading = true;
  String? _error;

  // Chat State
  List<WorkspaceConversation> _conversations = [];
  WorkspaceConversation? _currentConversation;
  List<WorkspaceMessage> _messages = [];
  bool _isLoadingMessages = false;
  bool _isSending = false;

  // Streaming & Generation State
  String _streamingText = '';
  final List<ChatStep> _currentSteps = [];
  final List<GeneratedAction> _generatedActions = [];

  // Filter & Tools State
  final Set<String> _selectedColors = {};
  final List<String> _availableColors = ['red', 'yellow', 'green', 'blue', 'purple'];
  final Set<String> _selectedTools = {};

  // UI State
  bool _isChatPanelVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWorkspaceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA LOADING
  // ===========================================================================

  Future<void> _loadWorkspaceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _workspaceService.getWorkspace(widget.workspaceId),
        _workspaceService.getWorkspaceDocuments(workspaceId: widget.workspaceId),
        _workspaceService.getWorkspaceConversations(widget.workspaceId),
      ]);

      if (!mounted) return;

      setState(() {
        _workspace = results[0] as WorkspaceModel;
        _documents = results[1] as List<WorkspaceDocumentBrief>;
        _conversations = results[2] as List<WorkspaceConversation>;
        _isLoading = false;

        // Auto-select first document
        if (_documents.isNotEmpty && _selectedDocumentId == null) {
          _selectedDocumentId = _documents.first.id;
        }

        // Auto-select most recent conversation
        if (_conversations.isNotEmpty) {
          _currentConversation = _conversations.first;
          _loadMessages();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_currentConversation == null) return;

    setState(() => _isLoadingMessages = true);

    try {
      final messages = await _workspaceService.getConversationMessages(
        _currentConversation!.id,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
        debugPrint('Error loading messages: $e');
      }
    }
  }

  // ===========================================================================
  // CHAT LOGIC
  // ===========================================================================

  Future<void> _createConversation() async {
    try {
      final newConversation = await _workspaceService.createWorkspaceConversation(
        widget.workspaceId,
      );
      if (mounted) {
        setState(() {
          _conversations.insert(0, newConversation);
          _currentConversation = newConversation;
          _messages = [];
          _currentSteps.clear();
          _generatedActions.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating conversation: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_currentConversation == null) {
      await _createConversation();
      if (_currentConversation == null) return;
    }

    HapticFeedback.lightImpact();
    _messageController.clear();

    // 1. Optimistic UI Update
    final userMessage = WorkspaceMessage(
      id: -1, // Temp ID
      conversationId: _currentConversation!.id,
      sender: 'user',
      text: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
      _streamingText = '';
      _currentSteps.clear();
      _generatedActions.clear();
    });
    _scrollToBottom();

    // 2. Persist User Message (Background)
    _workspaceService.saveMessage(
      conversationId: _currentConversation!.id,
      sender: 'user',
      text: text,
    ).catchError((e) {
      debugPrint('Error saving user message: $e');
      return WorkspaceMessage(id: -1, conversationId: _currentConversation!.id, sender: 'user', text: text, createdAt: '');
    });

    // 3. Build workspace metadata for color-filtered context
    Map<String, dynamic>? workspaceMetadata;
    if (_selectedColors.isNotEmpty || _selectedDocumentId != null) {
      workspaceMetadata = {
        if (_selectedDocumentId != null) 'document_id': _selectedDocumentId,
        if (_selectedColors.isNotEmpty) 'filter_colors': _selectedColors.toList(),
        'workspace_id': widget.workspaceId,
      };
      debugPrint('[WorkspaceChat] Using workspace metadata: $workspaceMetadata');
    }

    // 4. Stream Response with unified query endpoint
    try {
      final stream = _chatService.streamQuery(
        conversationId: _currentConversation!.id,
        query: text, // Send original query, context is handled by backend
        selectedTools: _selectedTools.toList(),
        chatType: 'workspace', // Use workspace chat type
        workspaceMetadata: workspaceMetadata,
      );

      await for (final event in stream) {
        if (!mounted) break;

        switch (event.type) {
          case ChatStreamEventType.chunk:
            if (event.chunk != null) {
              setState(() => _streamingText += event.chunk!);
              _scrollToBottom();
            }
            break;

          case ChatStreamEventType.step:
            if (event.content != null) {
              setState(() {
                final existingIndex = _currentSteps.indexWhere((s) => s.content == event.content);
                if (existingIndex != -1) {
                  _currentSteps[existingIndex] = ChatStep(
                    content: event.content!,
                    status: event.status ?? 'loading',
                  );
                } else {
                  _currentSteps.add(ChatStep(
                    content: event.content!,
                    status: event.status ?? 'loading',
                  ));
                }
              });
              _scrollToBottom();
            }
            break;

          case ChatStreamEventType.action:
            if (event.actionType != null && event.actionType != 'set_conversation_title') {
              setState(() {
                // Correctly instantiating GeneratedAction without getters in constructor
                _generatedActions.add(GeneratedAction(
                  type: event.actionType!,
                  id: event.actionId ?? 0,
                  name: event.actionName ?? 'Generated Item',
                  count: event.actionCount ?? 0,
                ));
              });
              _scrollToBottom();
            }
            break;

          case ChatStreamEventType.titleUpdate:
            if (event.title != null) {
              setState(() {
                _currentConversation = _currentConversation?.copyWith(title: event.title);
                final index = _conversations.indexWhere((c) => c.id == _currentConversation?.id);
                if (index != -1) {
                  _conversations[index] = _conversations[index].copyWith(title: event.title);
                }
              });
            }
            break;

          case ChatStreamEventType.error:
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${event.error}')),
              );
            }
            break;

          case ChatStreamEventType.done:
            await _finalizeBotMessage();
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stream Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _finalizeBotMessage() async {
    if (_streamingText.isEmpty) return;

    String? metadataJson;
    if (_currentSteps.isNotEmpty || _generatedActions.isNotEmpty) {
      final metadataMap = <String, dynamic>{};
      if (_currentSteps.isNotEmpty) {
        metadataMap['steps'] = _currentSteps.map((s) => {
          'content': s.content,
          'status': s.status,
        }).toList();
      }
      if (_generatedActions.isNotEmpty) {
        metadataMap['actions'] = _generatedActions.map((a) => {
          'type': a.type,
          'id': a.id,
          'name': a.name,
          'count': a.count,
        }).toList();
      }
      metadataJson = jsonEncode(metadataMap);
    }

    final botMessage = WorkspaceMessage(
      id: -2,
      conversationId: _currentConversation!.id,
      sender: 'bot',
      text: _streamingText,
      createdAt: DateTime.now().toIso8601String(),
      metadata: metadataJson,
    );

    setState(() {
      _messages.add(botMessage);
      _streamingText = '';
      // We keep local state for steps briefly to prevent UI jumping,
      // but strictly relying on the added message is cleaner.
    });

    await _workspaceService.saveMessage(
      conversationId: _currentConversation!.id,
      sender: 'bot',
      text: botMessage.text,
      metadata: metadataJson,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > kDesktopBreakpoint;

        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null) {
          return _buildErrorState(context);
        }

        return isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context);
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading workspace: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadWorkspaceData, child: const Text('Retry'))
          ],
        ),
      ),
    );
  }

  // --- DESKTOP LAYOUT ---

  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(context, isDesktop: true),
          Expanded(
            child: Row(
              children: [
                // Left Panel: Files & Reader
                Expanded(
                  child: Column(
                    children: [
                      if (_documents.isNotEmpty)
                        _buildFileTabsBar(context),
                      Expanded(
                        child: _selectedDocumentId != null
                            ? DocumentReaderWidget(
                                documentId: _selectedDocumentId!,
                                workspaceId: widget.workspaceId,
                                workspaceService: _workspaceService,
                                onHighlightColorSelected: _toggleColorFilter,
                                onDocumentDeleted: _loadWorkspaceData,
                              )
                            : _buildNoDocumentSelected(context),
                      ),
                    ],
                  ),
                ),
                // Right Panel: Chat
                // We use AnimatedContainer for smooth toggling
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isChatPanelVisible ? 450 : 0,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      if (_isChatPanelVisible)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(-4, 0),
                        ),
                    ],
                  ),
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 450,
                      maxWidth: 450,
                      alignment: Alignment.topLeft,
                      child: _buildChatPanel(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !_isChatPanelVisible
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _isChatPanelVisible = true),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI Assistant'),
            )
          : null,
    );
  }

  // --- MOBILE LAYOUT ---

  Widget _buildMobileLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _workspace?.name ?? 'Workspace',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showEditCategoriesDialog(context),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(icon: const Icon(Icons.folder_outlined), text: l10n?.files ?? 'Files'),
            Tab(icon: const Icon(Icons.article_outlined), text: l10n?.read ?? 'Read'),
            Tab(icon: const Icon(Icons.auto_awesome_outlined), text: l10n?.chat ?? 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // UI/UX Improvement: Use KeepAlive to prevent reloading chat when switching tabs
        children: [
          _KeepAlivePage(child: _buildFileBrowser(context)),
          _KeepAlivePage(
            child: _selectedDocumentId != null
                ? DocumentReaderWidget(
                    documentId: _selectedDocumentId!,
                    workspaceId: widget.workspaceId,
                    workspaceService: _workspaceService,
                    onHighlightColorSelected: _toggleColorFilter,
                    onDocumentDeleted: _loadWorkspaceData,
                  )
                : _buildNoDocumentSelected(context),
          ),
          _KeepAlivePage(child: _buildChatPanel(context)),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-COMPONENTS
  // ===========================================================================

  void _toggleColorFilter(String color) {
    setState(() {
      if (_selectedColors.contains(color)) {
        _selectedColors.remove(color);
      } else {
        _selectedColors.add(color);
      }
    });
  }

  Widget _buildHeader(BuildContext context, {required bool isDesktop}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: colorScheme.primaryContainer,
               borderRadius: BorderRadius.circular(8),
             ),
             child: Icon(Icons.work, size: 20, color: colorScheme.onPrimaryContainer),
           ),
           const SizedBox(width: 12),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(_workspace?.name ?? 'Workspace', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               if (_workspace?.description != null)
                 Text(_workspace!.description!, style: Theme.of(context).textTheme.bodySmall),
             ],
           ),
           const Spacer(),
           IconButton(
             onPressed: () => _showEditCategoriesDialog(context),
             icon: const Icon(Icons.settings_outlined),
             tooltip: 'Workspace Settings',
           ),
           if (isDesktop && _isChatPanelVisible)
             IconButton(
               onPressed: () => setState(() => _isChatPanelVisible = false),
               icon: const Icon(Icons.close_fullscreen_outlined),
               tooltip: 'Hide Chat',
             ),
        ],
      ),
    );
  }

  Widget _buildFileTabsBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          final isSelected = doc.id == _selectedDocumentId;
          return Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedDocumentId = doc.id),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.surfaceContainerHighest : Colors.transparent,
                  border: isSelected ? Border(
                    top: BorderSide(color: colorScheme.primary, width: 2),
                    left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                    right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ) : null,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Icon(_getFileIcon(doc.title), size: 16, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      doc.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context) {
    return Column(
      children: [
        _buildChatHeader(context),
        const Divider(height: 1),
        _buildColorFilters(context),
        Expanded(
          child: _messages.isEmpty && _streamingText.isEmpty
              ? _buildChatEmptyState(context)
              : _buildMessagesList(context),
        ),
        _buildChatInput(context),
      ],
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < kDesktopBreakpoint;

    // Show streaming UI if active
    final showStreamingItem = _streamingText.isNotEmpty || _currentSteps.isNotEmpty || _isSending;
    final totalCount = _messages.length + (showStreamingItem ? 1 : 0);

    return ListView.builder(
      controller: _chatScrollController,
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: isMobile ? 80 : 32 // Extra padding at bottom
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          // --- Streaming Bubble ---
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSending && _currentSteps.isEmpty && _streamingText.isEmpty)
                _buildTypingIndicator(colorScheme),
              if (_currentSteps.isNotEmpty)
                _MinimalStepsPanel(steps: List.from(_currentSteps)),
              if (_streamingText.isNotEmpty)
                _MinimalMessageBubble(
                  message: WorkspaceMessage(
                    id: -3,
                    conversationId: _currentConversation?.id ?? 0,
                    sender: 'bot',
                    text: _streamingText,
                    createdAt: DateTime.now().toIso8601String(),
                  ),
                  isUser: false,
                  isStreaming: true,
                  colorScheme: colorScheme,
                  isMobile: isMobile,
                ),
              if (_generatedActions.isNotEmpty)
                _MinimalActionsWidget(
                  actions: _generatedActions,
                  isMobile: isMobile,
                  onNavigate: (action) => context.go(action.routePath),
                ),
            ],
          );
        }

        // --- Standard Message ---
        final message = _messages[index];
        final isUser = message.sender == 'user';
        final isBot = message.sender == 'bot';
        final isLastMessage = index == _messages.length - 1;

        // Parse Metadata
        MessageMetadata? parsedMetadata;
        if (message.metadata != null && message.metadata!.isNotEmpty) {
          try {
            final metaJson = jsonDecode(message.metadata!) as Map<String, dynamic>;
            final stepsList = (metaJson['steps'] as List?) ?? [];
            final actionsList = (metaJson['actions'] as List?) ?? [];

            parsedMetadata = MessageMetadata(
              steps: stepsList.map((s) => MessageStep(
                content: s['content']?.toString() ?? '',
                status: s['status']?.toString() ?? 'complete',
              )).toList(),
              actions: actionsList.map((a) => MessageAction(
                type: a['type']?.toString() ?? '',
                id: int.tryParse(a['id'].toString()) ?? 0,
                name: a['name']?.toString() ?? '',
                count: int.tryParse(a['count'].toString()) ?? 0,
              )).toList(),
            );
          } catch (_) {}
        }

        final bool hasLiveSteps = _currentSteps.isNotEmpty;
        final bool hasLiveActions = _generatedActions.isNotEmpty;
        final bool showPersistedSteps = isBot && (parsedMetadata?.steps?.isNotEmpty ?? false) && (!isLastMessage || !hasLiveSteps);
        final bool showPersistedActions = isBot && (parsedMetadata?.actions?.isNotEmpty ?? false) && (!isLastMessage || !hasLiveActions);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPersistedSteps)
              _MinimalPersistedStepsPanel(steps: parsedMetadata!.steps!),

            _MinimalMessageBubble(
              message: message,
              isUser: isUser,
              isStreaming: false,
              colorScheme: colorScheme,
              isMobile: isMobile,
            ),

            if (showPersistedActions)
              _MinimalPersistedActionsWidget(
                actions: parsedMetadata!.actions!,
                isMobile: isMobile,
                onNavigate: (action) {
                  context.go(action.type == 'flashcards' ? '/flashcards' : '/tests');
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildChatInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Tools Chips
            if (_selectedTools.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedTools.length,
                    separatorBuilder: (_,__) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return Chip(
                        label: Text(_selectedTools.elementAt(index)),
                        onDeleted: () => setState(() => _selectedTools.remove(_selectedTools.elementAt(index))),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 12),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        side: BorderSide.none,
                      );
                    },
                  ),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Tools Button
                IconButton(
                  onPressed: () => _showToolsBottomSheet(context),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: _selectedTools.isNotEmpty ? colorScheme.primary : colorScheme.onSurfaceVariant
                  ),
                  tooltip: 'Add Tools',
                ),
                const SizedBox(width: 8),
                // Text Field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: l10n?.type_message ?? 'Ask AI...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send Button
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isSending ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isSending
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onSurfaceVariant))
                          : Icon(Icons.arrow_upward_rounded, color: colorScheme.onPrimary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 48, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('Ask about your document', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Select highlighted text to focus the AI,\nor try a quick action below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickAction('Summarize', Icons.short_text),
                _buildQuickAction('Generate Flashcards', Icons.style),
                _buildQuickAction('Quiz Me', Icons.quiz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {
        _messageController.text = label;
        _sendMessage();
      },
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentConversation?.title ?? 'New Conversation',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<WorkspaceConversation?>(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onSelected: (conv) {
              if (conv == null) _createConversation();
              else {
                setState(() {
                  _currentConversation = conv;
                  _messages = [];
                });
                _loadMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('+ New Conversation')),
              const PopupMenuDivider(),
              ..._conversations.map((c) => PopupMenuItem(value: c, child: Text(c.title ?? 'Untitled'))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildColorFilters(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colorMap = {
      'red': isDark ? Colors.red[400]! : Colors.red,
      'yellow': isDark ? Colors.yellow[600]! : Colors.amber,
      'green': isDark ? Colors.green[400]! : Colors.green,
      'blue': isDark ? Colors.blue[400]! : Colors.blue,
      'purple': isDark ? Colors.purple[300]! : Colors.purple,
    };

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Center(child: Text('Focus context: ', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))),
          ..._availableColors.map((color) {
            final isSelected = _selectedColors.contains(color);
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                showCheckmark: false,
                selected: isSelected,
                label: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: colorMap[color], shape: BoxShape.circle),
                ),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                onSelected: (_) => _toggleColorFilter(color),
                visualDensity: VisualDensity.compact,
                side: isSelected ? BorderSide(color: colorMap[color]!, width: 2) : BorderSide.none,
                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)),
            const SizedBox(width: 8),
            Text('AI is thinking...', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileBrowser(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No documents uploaded'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final isSelected = doc.id == _selectedDocumentId;
        return Card(
          elevation: 0,
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(_getFileIcon(doc.title), color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(doc.categoryName ?? 'Uncategorized'),
            onTap: () {
              setState(() => _selectedDocumentId = doc.id);
              if (MediaQuery.of(context).size.width < kDesktopBreakpoint) {
                _tabController.animateTo(1);
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  Widget _buildNoDocumentSelected(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('Select a document to start reading'),
        ],
      ),
    );
  }

  void _showToolsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Text('Available Tools', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildToolTile(context, setModalState, 'Wiedza z plików', 'Search uploaded documents', Icons.search),
                _buildToolTile(context, setModalState, 'Generowanie fiszek', 'Create flashcards', Icons.style),
                _buildToolTile(context, setModalState, 'Generowanie egzaminu', 'Create practice exam', Icons.quiz),
                _buildToolTile(context, setModalState, 'Wyszukaj w internecie', 'Web search', Icons.public),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildToolTile(BuildContext context, StateSetter setModalState, String id, String name, IconData icon) {
    final isSelected = _selectedTools.contains(id);
    final colorScheme = Theme.of(context).colorScheme;
    return CheckboxListTile(
      value: isSelected,
      onChanged: (val) {
        setModalState(() {
          if (val == true) _selectedTools.add(id);
          else _selectedTools.remove(id);
        });
        setState(() {}); // Update parent UI
      },
      title: Text(name),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      activeColor: colorScheme.primary,
    );
  }

  IconData _getFileIcon(String filename) {
    if (filename.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (filename.endsWith('.doc') || filename.endsWith('.docx')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Future<void> _showEditCategoriesDialog(BuildContext context) async {
    if (_workspace == null) return;
    final result = await showDialog(
      context: context,
      builder: (context) => WorkspaceFormDialog(workspace: _workspace),
    );
    if (result != null) _loadWorkspaceData();
  }
}

// =============================================================================
// SUB-WIDGETS (Minimal Components for Chat)
// =============================================================================

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
  @override
  bool get wantKeepAlive => true;
}

class _MinimalMessageBubble extends StatelessWidget {
  final WorkspaceMessage message;
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        constraints: BoxConstraints(maxWidth: isMobile ? 300 : 380),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: MarkdownBody(
          data: message.text + (isStreaming ? ' ▌' : ''),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: colorScheme.onSurface, fontSize: 15),
            code: TextStyle(backgroundColor: colorScheme.surface, fontFamily: 'monospace', fontSize: 13),
            codeblockDecoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
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
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loading = widget.steps.any((s) => s.status == 'loading');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.outlineVariant, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                if (loading) SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                else Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Text(loading ? 'Thinking Process...' : 'Process Completed', style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${step.content}', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MinimalPersistedStepsPanel extends StatelessWidget {
  final List<MessageStep> steps;
  const _MinimalPersistedStepsPanel({required this.steps});

  @override
  Widget build(BuildContext context) {
    // Reusing the same logic but for static data, simplified for brevity
    final colorScheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: Text('Thought Process', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      leading: const Icon(Icons.psychology, size: 16),
      dense: true,
      visualDensity: VisualDensity.compact,
      shape: const Border(),
      collapsedShape: const Border(),
      children: steps.map((s) => ListTile(
        visualDensity: VisualDensity.compact,
        dense: true,
        leading: const Icon(Icons.circle, size: 6),
        title: Text(s.content, style: const TextStyle(fontSize: 12)),
      )).toList(),
    );
  }
}

class _MinimalActionsWidget extends StatelessWidget {
  final List<GeneratedAction> actions;
  final bool isMobile;
  final Function(GeneratedAction) onNavigate;

  const _MinimalActionsWidget({required this.actions, required this.isMobile, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((a) => ActionChip(
        avatar: Icon(a.type == 'flashcards' ? Icons.style : Icons.quiz, size: 16),
        label: Text(a.label),
        onPressed: () => onNavigate(a),
      )).toList(),
    );
  }
}

class _MinimalPersistedActionsWidget extends StatelessWidget {
  final List<MessageAction> actions;
  final bool isMobile;
  final Function(MessageAction) onNavigate;

  const _MinimalPersistedActionsWidget({required this.actions, required this.isMobile, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((a) => ActionChip(
        avatar: Icon(a.type == 'flashcards' ? Icons.style : Icons.quiz, size: 16),
        label: Text('${a.name} (${a.count})'),
        onPressed: () => onNavigate(a),
      )).toList(),
    );
  }
}