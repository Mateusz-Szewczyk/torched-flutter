import 'dart:convert';
import 'dart:ui';
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

// ============================================================================
// THEME HELPER - Uses colors from theme.dart (AppTheme)
// ============================================================================
class _ThemeHelper {
  // Accent gradient - using brand orange colors from theme.dart
  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)], // Brand orange
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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

  // Key for popup menu positioning
  final GlobalKey _conversationPillKey = GlobalKey();

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
    // Delegate to the new method with feedback
    await _createNewConversationWithFeedback();
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

    // 3. Build workspace metadata for color-filtered context and LLM awareness
    Map<String, dynamic>? workspaceMetadata;
    // Always build metadata for workspace chat to include workspace info
    final selectedDocument = _documents.firstWhere(
      (d) => d.id == _selectedDocumentId,
      orElse: () => WorkspaceDocumentBrief(id: '', title: '', categoryName: null, createdAt: ''),
    );

    workspaceMetadata = {
      'workspace_id': widget.workspaceId,
      if (_workspace?.name != null) 'workspace_name': _workspace!.name,
      if (_workspace?.description != null && _workspace!.description!.isNotEmpty)
        'workspace_description': _workspace!.description,
      if (_selectedDocumentId != null) 'document_id': _selectedDocumentId,
      if (_selectedDocumentId != null && selectedDocument.title.isNotEmpty)
        'document_name': selectedDocument.title,
      if (_selectedColors.isNotEmpty) 'filter_colors': _selectedColors.toList(),
    };
    debugPrint('[WorkspaceChat] Using workspace metadata: $workspaceMetadata');

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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(context, isDesktop: true),
          Expanded(
            child: Row(
              children: [
                // Left Panel: Files & Reader (Focus Zone)
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
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
                ),
                // Right Panel: Chat
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isChatPanelVisible ? 450 : 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: isDark ? 10.0 : 0,
                        sigmaY: isDark ? 10.0 : 0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(isDark ? 0.9 : 1),
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.outlineVariant.withOpacity(isDark ? 0.1 : 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: OverflowBox(
                          minWidth: 450,
                          maxWidth: 450,
                          alignment: Alignment.topLeft,
                          child: _buildChatPanel(context),
                        ),
                      ),
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
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isDark ? 8.0 : 0,
          sigmaY: isDark ? 8.0 : 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(isDark ? 0.9 : 0.95),
            // No hard border - use subtle shadow instead
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.tertiary.withOpacity(0.2),
                      colorScheme.tertiary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.work_outline_rounded,
                  size: 20,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workspace?.name ?? 'Workspace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_workspace?.description != null && _workspace!.description!.isNotEmpty)
                      Text(
                        _workspace!.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Settings button with subtle styling
              _GhostIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Workspace Settings',
                onPressed: () => _showEditCategoriesDialog(context),
                colorScheme: colorScheme,
              ),
              if (isDesktop && _isChatPanelVisible) ...[
                const SizedBox(width: 4),
                _GhostIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Hide Chat',
                  onPressed: () => setState(() => _isChatPanelVisible = false),
                  colorScheme: colorScheme,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTabsBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: _documents.map((doc) {
            final isSelected = doc.id == _selectedDocumentId;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedDocumentId = doc.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.tertiaryContainer.withOpacity(isDark ? 0.2 : 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(
                            color: colorScheme.tertiary.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.tertiary.withOpacity(0.1),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFileIcon(doc.title),
                        size: 14,
                        color: isSelected
                            ? colorScheme.tertiary
                            : colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        doc.title.length > 20
                            ? '${doc.title.substring(0, 17)}...'
                            : doc.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
                          color: isSelected
                              ? (isDark ? Colors.white : colorScheme.onSurface)
                              : colorScheme.onSurfaceVariant.withOpacity(0.7),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    return Stack(
      children: [
        // Main Chat Area
        Positioned.fill(
          child: Column(
            children: [
              _buildChatHeader(context),
              // Removed divider - using spacing instead
              const SizedBox(height: 4),
              _buildColorFilters(context),
              Expanded(
                child: _messages.isEmpty && _streamingText.isEmpty
                    ? _buildChatEmptyState(context)
                    : _buildMessagesList(context),
              ),
              // Spacer to prevent content from being hidden behind the floating input
              SizedBox(height: isDesktop ? 130 : 110),
            ],
          ),
        ),
        // Input Area (Positioned for floating effect)
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
        bottom: isMobile ? 160 : 180 // Extra padding for floating input
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
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      return _buildDesktopChatInput(context, colorScheme, l10n);
    }
    return _buildMobileChatInput(context, colorScheme, l10n);
  }

  Widget _buildMobileChatInput(BuildContext context, ColorScheme colorScheme, AppLocalizations? l10n) {
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
                if (_selectedTools.isNotEmpty)
                  _buildToolsChipsList(colorScheme),

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
                        child: _WorkspaceToolsButton(
                          hasTools: _selectedTools.isNotEmpty,
                          toolCount: _selectedTools.length,
                          onPressed: () => _showToolsBottomSheet(context),
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChatTextField(l10n, colorScheme, false),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _WorkspaceSendButton(
                          isSending: _isSending,
                          onPressed: _sendMessage,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopChatInput(BuildContext context, ColorScheme colorScheme, AppLocalizations? l10n) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        margin: const EdgeInsets.only(bottom: 28, left: 20, right: 20),
        decoration: BoxDecoration(
          // Gradient border effect using tertiary color
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    colorScheme.tertiary.withOpacity(0.25),
                    colorScheme.tertiary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(1), // Border width
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.95),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              if (isDark)
                BoxShadow(
                  color: colorScheme.tertiary.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedTools.isNotEmpty)
                _buildToolsChipsList(colorScheme),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _WorkspaceToolsButton(
                      hasTools: _selectedTools.isNotEmpty,
                      toolCount: _selectedTools.length,
                      onPressed: () => _showToolsBottomSheet(context),
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChatTextField(l10n, colorScheme, true),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _FuturisticSendButton(
                      isSending: _isSending,
                      onPressed: _sendMessage,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsChipsList(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedTools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tool = _selectedTools.elementAt(index);
          return _WorkspaceToolChip(
            label: _getToolShortName(tool),
            onRemove: () => setState(() => _selectedTools.remove(tool)),
            colorScheme: colorScheme,
          );
        },
      ),
    );
  }

  Widget _buildChatTextField(AppLocalizations? l10n, ColorScheme colorScheme, bool isDesktop) {
    final textField = TextField(
      controller: _messageController,
      focusNode: _inputFocusNode,
      minLines: 1,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      scrollPhysics: const ClampingScrollPhysics(),
      style: TextStyle(
        fontSize: 16,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: false,
        hintText: _selectedColors.isNotEmpty
            ? 'Ask about ${_selectedColors.join(", ")} highlights...'
            : (l10n?.type_message ?? 'Message...'),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.85),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      ),
    );

    if (isDesktop) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!HardwareKeyboard.instance.isShiftPressed) {
              _sendMessage();
            }
          },
        },
        child: textField,
      );
    }

    return textField;
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

  Widget _buildChatEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          // Animated Icon Container with gradient glow
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.tertiary.withOpacity(isDark ? 0.15 : 0.1),
                  colorScheme.tertiary.withOpacity(isDark ? 0.05 : 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: colorScheme.tertiary.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Ready to study?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Highlight text to focus the AI,\nor try a quick action below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
              height: 1.6,
              fontSize: 14,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 32),

          // Quick Actions Grid - Futuristic Pills
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _FuturisticQuickAction(
                label: 'Summarize',
                icon: Icons.short_text_rounded,
                color: colorScheme.tertiary,
                onTap: () {
                  _messageController.text = 'Summarize this document';
                  _sendMessage();
                },
              ),
              _FuturisticQuickAction(
                label: 'Flashcards',
                icon: Icons.style_rounded,
                color: colorScheme.tertiary.withOpacity(0.85),
                onTap: () {
                  _messageController.text = 'Create flashcards from this document';
                  _sendMessage();
                },
              ),
              _FuturisticQuickAction(
                label: 'Quiz Me',
                icon: Icons.quiz_rounded,
                color: colorScheme.tertiary.withOpacity(0.7),
                onTap: () {
                  _messageController.text = 'Create a quiz to test my knowledge';
                  _sendMessage();
                },
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Hint about color filters - Glass card style
          if (_selectedColors.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(isDark ? 0.1 : 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Use color filters above to focus on specific highlights',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > kDesktopBreakpoint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Centered Context Pill with Add Button
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : screenWidth * 0.85,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The Interactive Context Pill
                  Flexible(
                    child: _ContextPill(
                      key: _conversationPillKey,
                      conversationTitle: _currentConversation?.title ?? 'New Conversation',
                      workspaceName: _workspace?.name ?? '',
                      hasMultipleConversations: _conversations.length > 1,
                      onTap: () => _showConversationSelector(context),
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Integrated Add Button - subtle circle next to pill
                  _AddConversationButton(
                    onPressed: _createNewConversationWithFeedback,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a new conversation with visual feedback
  Future<void> _createNewConversationWithFeedback() async {
    // Show loading indicator briefly
    setState(() => _isSending = true);

    try {
      final newConversation = await _workspaceService.createWorkspaceConversation(
        widget.workspaceId,
      );

      if (mounted) {
        // Haptic feedback for success
        HapticFeedback.mediumImpact();

        setState(() {
          _conversations.insert(0, newConversation);
          _currentConversation = newConversation;
          _messages = [];
          _currentSteps.clear();
          _generatedActions.clear();
          _streamingText = '';
          _isSending = false;
        });

        // Show confirmation snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('New conversation started'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Focus on input field
        _inputFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating conversation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Switches to a different conversation
  void _switchConversation(WorkspaceConversation conv) {
    if (conv.id == _currentConversation?.id) return;

    HapticFeedback.selectionClick();

    setState(() {
      _currentConversation = conv;
      _messages = [];
      _currentSteps.clear();
      _generatedActions.clear();
      _streamingText = '';
    });

    _loadMessages();
  }

  /// Shows a selector for conversations - uses PopupMenu dropdown on desktop, BottomSheet on mobile
  void _showConversationSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > kDesktopBreakpoint;

    // On desktop, use PopupMenu dropdown positioned under the pill
    if (isDesktop) {
      _showDesktopConversationDropdown(context, colorScheme);
      return;
    }

    // On mobile, use bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _buildConversationSelectorContent(context, colorScheme, isDesktop: false),
      ),
    );
  }

  /// Shows desktop dropdown using showMenu (like CategoryDropdown)
  void _showDesktopConversationDropdown(BuildContext context, ColorScheme colorScheme) {
    final RenderBox? renderBox = _conversationPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height + 4,
        screenSize.width - buttonPosition.dx - buttonSize.width,
        0,
      ),
      constraints: BoxConstraints(
        minWidth: buttonSize.width.clamp(300.0, 420.0),
        maxWidth: buttonSize.width.clamp(300.0, 420.0),
        maxHeight: 450,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      items: _buildConversationMenuItems(colorScheme, theme),
    ).then((value) {
      if (value == '__new__') {
        _createNewConversationWithFeedback();
      } else if (value != null) {
        // Find and switch to conversation
        final conv = _conversations.firstWhere(
          (c) => c.id.toString() == value,
          orElse: () => _conversations.first,
        );
        _switchConversation(conv);
      }
    });
  }

  /// Builds menu items for conversation dropdown
  List<PopupMenuEntry<String>> _buildConversationMenuItems(ColorScheme colorScheme, ThemeData theme) {
    final List<PopupMenuEntry<String>> items = [];

    // New Conversation Button at the top
    items.add(PopupMenuItem<String>(
      value: '__new__',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'New Conversation',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ));

    if (_conversations.isNotEmpty) {
      // Divider
      items.add(const PopupMenuDivider(height: 8));

      // Section header
      items.add(PopupMenuItem<String>(
        enabled: false,
        height: 32,
        child: Text(
          'RECENT CONVERSATIONS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 10,
          ),
        ),
      ));

      // Conversation items
      for (final conv in _conversations) {
        final isSelected = conv.id == _currentConversation?.id;
        items.add(PopupMenuItem<String>(
          value: conv.id.toString(),
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
                        : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conv.title ?? 'Untitled',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatConversationDate(conv.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
              ],
            ),
          ),
        ));
      }
    }

    return items;
  }

  /// Builds the shared content for conversation selector (used in BottomSheet for mobile)
  Widget _buildConversationSelectorContent(BuildContext context, ColorScheme colorScheme, {required bool isDesktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar (only for mobile bottom sheet)
        if (!isDesktop)
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        // Sticky Header with "New Conversation" button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              // New Conversation Button - Large & Prominent
              Material(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _createNewConversationWithFeedback();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: colorScheme.onPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Start New Conversation',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Recent Conversations Label
              if (_conversations.isNotEmpty)
                Row(
                  children: [
                    Text(
                      'RECENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_conversations.length} conversation${_conversations.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Divider
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),

        // Conversation List
        Flexible(
          child: _conversations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 40,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isSelected = conv.id == _currentConversation?.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isSelected
                            ? colorScheme.primaryContainer.withOpacity(0.4)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _switchConversation(conv);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Selection indicator
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title & Date
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conv.title ?? 'Untitled',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatConversationDate(conv.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Arrow indicator
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Safe area padding (only for mobile)
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  /// Formats conversation date for display
  String _formatConversationDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return '';
    }
  }

  Widget _buildColorFilters(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Neon-inspired color palette for dark mode
    final colorMap = {
      'red': isDark ? const Color(0xFFFF6B6B) : Colors.red[500]!,
      'yellow': isDark ? const Color(0xFFFFD93D) : Colors.amber[600]!,
      'green': isDark ? const Color(0xFF6BCB77) : Colors.green[500]!,
      'blue': isDark ? const Color(0xFF4D96FF) : Colors.blue[500]!,
      'purple': isDark ? const Color(0xFFB983FF) : Colors.purple[500]!,
    };

    const double chipSize = 28.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Label with subtle styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Focus',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Color chips
          Expanded(
            child: Row(
              children: _availableColors.map((color) {
                final isSelected = _selectedColors.contains(color);
                final colorValue = colorMap[color]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _toggleColorFilter(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: chipSize,
                      height: chipSize,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorValue
                            : colorValue.withOpacity(isDark ? 0.12 : 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : colorValue.withOpacity(isDark ? 0.35 : 0.25),
                          width: 1.5,
                        ),
                        boxShadow: isSelected && isDark
                            ? [
                                BoxShadow(
                                  color: colorValue.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white : Colors.white,
                                  key: const ValueKey('check'),
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Clear button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _selectedColors.isNotEmpty ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _selectedColors.isNotEmpty ? null : 0,
              child: _selectedColors.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() => _selectedColors.clear()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : colorScheme.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Take first 4 documents for quick access
    final quickAccessDocs = _documents.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Text(
            'Welcome back! 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a document from above to start studying, or pick one from your recent files.',
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Quick Access Section
          if (quickAccessDocs.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: quickAccessDocs.length,
              itemBuilder: (context, index) {
                final doc = quickAccessDocs[index];
                return _buildQuickAccessCard(context, doc, isDark, colorScheme);
              },
            ),
          ] else ...[
            // Empty state when no documents
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.folder_open_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No documents yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload files in My Files to see them here',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    WorkspaceDocumentBrief doc,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedDocumentId = doc.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getFileIcon(doc.title),
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              // File Name
              Text(
                doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              if (doc.categoryName != null) ...[
                const SizedBox(height: 4),
                Text(
                  doc.categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
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

/// Chat Avatar - identical to chat_screen.dart
class _WorkspaceChatAvatar extends StatelessWidget {
  final bool isUser;
  final ColorScheme colorScheme;

  const _WorkspaceChatAvatar({required this.isUser, required this.colorScheme});

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

/// Minimal message bubble - clean, no-background style for bot messages
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
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        bottom: 8,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 24,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot Avatar (Left)
          if (!isUser) ...[
            _WorkspaceChatAvatar(isUser: false, colorScheme: colorScheme),
            const SizedBox(width: 12),
          ],

          // Message Content
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 16 : 4,
                vertical: isUser ? 12 : 4,
              ),
              decoration: isUser
                  ? BoxDecoration(
                      // User messages: Match chat_screen.dart style
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null, // No background for bot messages - clean look
              child: MarkdownBody(
                data: message.text + (isStreaming ? ' ▌' : ''),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: colorScheme.onSurface, // Same for both user and bot
                    fontSize: isMobile ? 15 : 16,
                    height: 1.6,
                  ),
                  h1: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                  h2: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                  h3: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  listBullet: TextStyle(
                    color: colorScheme.tertiary,
                  ),
                  code: TextStyle(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.tertiary,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: colorScheme.tertiary,
                        width: 3,
                      ),
                    ),
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
  // Default to collapsed
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < kDesktopBreakpoint;
    final isDark = theme.brightness == Brightness.dark;

    // Determine if we are still processing
    final bool isThinking =
        widget.steps.any((step) => step.status == 'loading');
    final int completedCount = widget.steps.where((s) => s.status == 'complete').length;

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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isThinking)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.tertiary,
                      ),
                    )
                  else
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colorScheme.tertiary,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    isThinking
                        ? 'Reasoning...'
                        : 'Processed $completedCount step${completedCount == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12, left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.steps
                    .map((step) => _WorkspaceStepItem(
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

class _WorkspaceStepItem extends StatelessWidget {
  final ChatStep step;
  final ColorScheme colorScheme;

  const _WorkspaceStepItem({required this.step, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isLoading = step.status == 'loading';
    final isComplete = step.status == 'complete';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLoading
                    ? colorScheme.tertiary
                    : (isComplete
                        ? colorScheme.tertiary
                        : colorScheme.onSurfaceVariant.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.content,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isLoading
                    ? colorScheme.tertiary
                    : colorScheme.onSurfaceVariant.withOpacity(0.8),
                letterSpacing: -0.1,
              ),
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

// =============================================================================
// WORKSPACE CHAT INPUT HELPER WIDGETS (Matching chat_screen.dart style)
// =============================================================================

class _WorkspaceToolsButton extends StatelessWidget {
  final bool hasTools;
  final int toolCount;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _WorkspaceToolsButton({
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

class _WorkspaceSendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _WorkspaceSendButton({
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

class _WorkspaceToolChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final ColorScheme colorScheme;

  const _WorkspaceToolChip({
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

/// Interactive Context Pill - Shows conversation title and workspace name in a styled container
class _ContextPill extends StatelessWidget {
  final String conversationTitle;
  final String workspaceName;
  final bool hasMultipleConversations;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ContextPill({
    super.key,
    required this.conversationTitle,
    required this.workspaceName,
    required this.hasMultipleConversations,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Icon
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.2),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              // Title
              Flexible(
                child: Text(
                  conversationTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Separator & Workspace Name (if available)
              if (workspaceName.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 14,
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
                Flexible(
                  child: Text(
                    workspaceName,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              // Dropdown indicator
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle circular add button that sits next to the Context Pill
class _AddConversationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _AddConversationButton({
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New Conversation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}


// =============================================================================
// FUTURISTIC HELPER WIDGETS
// =============================================================================

/// Ghost icon button - subtle, transparent styling for header actions
class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _GhostIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark
              ? Colors.white.withOpacity(0.05)
              : colorScheme.onSurface.withOpacity(0.05),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Futuristic send button with gradient accent and hover animation
class _FuturisticSendButton extends StatefulWidget {
  final bool isSending;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _FuturisticSendButton({
    required this.isSending,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  State<_FuturisticSendButton> createState() => _FuturisticSendButtonState();
}

class _FuturisticSendButtonState extends State<_FuturisticSendButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isSending ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          transform: Matrix4.identity()
            ..scale(_isHovered && !widget.isSending ? 1.08 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.isSending
                ? null
                : LinearGradient(
                    colors: _isHovered
                        ? [const Color(0xFFFFAA00), const Color(0xFFFF8C00)] // Brighter on hover
                        : [const Color(0xFFFF8C00), const Color(0xFFFF6B00)], // Brand orange
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.isSending ? widget.colorScheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isSending
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withOpacity(_isHovered ? 0.5 : 0.3),
                      blurRadius: _isHovered ? 16 : 12,
                      spreadRadius: _isHovered ? 2 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isSending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  )
                : AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isHovered ? -0.05 : 0,
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Futuristic quick action button for empty state
class _FuturisticQuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FuturisticQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? color.withOpacity(0.2)
                  : colorScheme.outlineVariant.withOpacity(0.2),
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.05),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

