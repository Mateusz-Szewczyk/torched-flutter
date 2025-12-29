import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import '../data/repositories/conversation_repository.dart';

class ChatStep {
  final String content;
  final String status;
  ChatStep({required this.content, required this.status});
}

/// Model for a generated action (flashcards/exam)
class GeneratedAction {
  final String type;  // "flashcards" or "exam"
  final int id;
  final String name;
  final int count;

  GeneratedAction({
    required this.type,
    required this.id,
    required this.name,
    required this.count,
  });

  String get itemLabel => type == 'flashcards' ? 'fiszek' : 'pytań';
  String get routePath => type == 'flashcards' ? '/flashcards' : '/tests';

  /// Label to display on the navigation button
  String get label {
    final icon = type == 'flashcards' ? '📚' : '📝';
    return '$icon $name ($count $itemLabel)';
  }
}

/// Provider for managing conversations and chat state
/// Uses Repository pattern with local cache for optimistic UI
class ConversationProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ConversationRepository _repository = ConversationRepository();

  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<List<Message>>? _messagesSubscription;

  // ============================================================================
  // STATE
  // ============================================================================

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  int? _currentConversationId;
  int? get currentConversationId => _currentConversationId;

  List<Message> _messages = [];
  List<Message> get messages => _messages;

  List<ChatStep> _currentSteps = [];
  List<ChatStep> get currentSteps => _currentSteps;

  // Generated actions for navigation buttons
  List<GeneratedAction> _generatedActions = [];
  List<GeneratedAction> get generatedActions => _generatedActions;

  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;

  bool _isLoadingMessages = false;
  bool get isLoadingMessages => _isLoadingMessages;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _error;
  String? get error => _error;

  // Streaming state
  String _streamingText = '';
  String get streamingText => _streamingText;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  StreamSubscription? _streamSubscription;

  // Selected tools
  List<String> _selectedTools = [];
  List<String> get selectedTools => _selectedTools;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  ConversationProvider() {
    // Subscribe to repository streams for reactive updates
    _conversationsSubscription = _repository.conversationsStream.listen((convs) {
      _conversations = convs..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    });
  }

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  Conversation? get currentConversation {
    if (_currentConversationId == null) return null;
    try {
      return _conversations.firstWhere((c) => c.id == _currentConversationId);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // CONVERSATION OPERATIONS (with Optimistic UI)
  // ============================================================================

  /// Fetch all conversations - uses cache-first strategy
  Future<void> fetchConversations({bool forceRefresh = false}) async {
    _isLoadingConversations = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _repository.getConversations(forceRefresh: forceRefresh);
      _conversations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Create a new conversation with optimistic UI
  /// Note: Does NOT automatically set as current - caller should navigate
  Future<Conversation?> createConversation() async {
    // Haptic feedback for action
    HapticFeedback.lightImpact();

    try {
      final conversation = await _repository.createConversation();

      if (conversation != null) {
        // Don't set as current here - let the navigation handle it
        // This prevents issues with the setCurrentConversation check
        // _currentConversationId = conversation.id;

        // Clear any existing messages since we're creating a new conversation
        // but don't set it as current yet

        // Reload conversations to ensure list is up to date
        await fetchConversations();
      }

      return conversation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update conversation title with optimistic UI
  Future<bool> updateConversationTitle(int conversationId, String title) async {
    try {
      final success = await _repository.updateTitle(conversationId, title);

      if (success) {
        // Update local state (repository already updated cache)
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(title: title);
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a conversation with optimistic UI
  Future<bool> deleteConversation(int conversationId) async {
    // Haptic feedback for destructive action
    HapticFeedback.mediumImpact();

    // Store for potential rollback
    final deletedIndex = _conversations.indexWhere((c) => c.id == conversationId);
    final deletedConv = deletedIndex != -1 ? _conversations[deletedIndex] : null;

    // Optimistic removal from local state
    if (deletedIndex != -1) {
      _conversations.removeAt(deletedIndex);
      if (_currentConversationId == conversationId) {
        _currentConversationId = null;
        _messages = [];
      }
      notifyListeners();
    }

    try {
      final success = await _repository.deleteConversation(conversationId);

      if (!success && deletedConv != null) {
        // Rollback
        _conversations.insert(deletedIndex, deletedConv);
        notifyListeners();
      }

      return success;
    } catch (e) {
      // Rollback on error
      if (deletedConv != null) {
        _conversations.insert(deletedIndex, deletedConv);
        notifyListeners();
      }
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Set current conversation
  void setCurrentConversation(int? conversationId) {
    if (_currentConversationId != conversationId) {
      _currentConversationId = conversationId;
      _messages = [];
      _streamingText = '';
      _isStreaming = false;
      _currentSteps = [];
      notifyListeners();

      if (conversationId != null) {
        fetchMessages(conversationId);
      }
    }
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Fetch messages for the current conversation - uses cache
  Future<void> fetchMessages(int conversationId) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _repository.getMessages(conversationId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Send a message and get streaming response
  Future<void> sendMessage(String text) async {
    if (_currentConversationId == null || text.trim().isEmpty) return;
    if (_isSending || _isStreaming) return;

    final userText = text.trim();
    _isSending = true;
    _error = null;
    _generatedActions = []; // Clear previous actions

    // 1. Natychmiastowe dodanie wiadomości użytkownika do UI
    final userMessage = Message(
      role: 'user',
      content: userText,
      timestamp: DateTime.now().toIso8601String(),
    );
    _messages = [..._messages, userMessage];
    notifyListeners();

    // 2. Zapisanie wiadomości użytkownika na serwerze (asynchronicznie w tle)
    try {
      _chatService.saveMessage(
        conversationId: _currentConversationId!,
        sender: 'user',
        text: userText,
      );
    } catch (e) {
      debugPrint('Failed to save user message: $e');
    }

    // 3. Przygotowanie stanu do streamingu
    _isStreaming = true;
    _streamingText = '';
    _currentSteps = [];

    // Collect steps and actions during streaming for persistence
    final List<Map<String, String>> collectedSteps = [];
    final List<Map<String, dynamic>> collectedActions = [];

    notifyListeners();

    try {
      final stream = _chatService.streamQuery(
        conversationId: _currentConversationId!,
        query: userText,
        selectedTools: _selectedTools,
      );

      await for (final event in stream) {
        switch (event.type) {
          case ChatStreamEventType.step:
            if (event.content != null && event.status != null) {
              final index = _currentSteps.indexWhere((s) => s.content == event.content);

              if (index != -1) {
                _currentSteps[index] = ChatStep(
                  content: event.content!,
                  status: event.status!
                );
                // Update collected steps
                final stepIndex = collectedSteps.indexWhere((s) => s['content'] == event.content);
                if (stepIndex != -1) {
                  collectedSteps[stepIndex] = {
                    'content': event.content!,
                    'status': event.status!,
                  };
                }
              } else {
                _currentSteps.add(ChatStep(
                  content: event.content!,
                  status: event.status!
                ));
                // Add to collected steps
                collectedSteps.add({
                  'content': event.content!,
                  'status': event.status!,
                });
              }
              notifyListeners();
            }
            break;

          case ChatStreamEventType.chunk:
            _streamingText += event.chunk ?? '';
            notifyListeners();
            break;

          case ChatStreamEventType.action:
            // Dodaj akcję nawigacji do listy
            if (event.actionType != null && event.actionId != null) {
              final action = GeneratedAction(
                type: event.actionType!,
                id: event.actionId!,
                name: event.actionName ?? 'Nowy zestaw',
                count: event.actionCount ?? 0,
              );
              _generatedActions.add(action);

              // Add to collected actions for persistence
              collectedActions.add({
                'type': event.actionType!,
                'id': event.actionId!,
                'name': event.actionName ?? 'Nowy zestaw',
                'count': event.actionCount ?? 0,
              });
              notifyListeners();
            }
            break;

          case ChatStreamEventType.done:
            if (_streamingText.isNotEmpty) {
              // Build metadata JSON for persistence
              String? metadataJson;
              if (collectedSteps.isNotEmpty || collectedActions.isNotEmpty) {
                final metadata = <String, dynamic>{};
                if (collectedSteps.isNotEmpty) {
                  metadata['steps'] = collectedSteps;
                }
                if (collectedActions.isNotEmpty) {
                  metadata['actions'] = collectedActions;
                }
                metadataJson = jsonEncode(metadata);
              }

              // Create bot message with metadata
              final botMessage = Message(
                role: 'bot',
                content: _streamingText,
                timestamp: DateTime.now().toIso8601String(),
                metadata: metadataJson,
              );
              _messages = [..._messages, botMessage];

              // Trwały zapis odpowiedzi bota na serwerze z metadata
              await _chatService.saveMessage(
                conversationId: _currentConversationId!,
                sender: 'bot',
                text: _streamingText,
                metadata: metadataJson,
              );
            }

            _isStreaming = false;
            _streamingText = '';
            _selectedTools = []; // Czyścimy narzędzia po udanym zapytaniu
            break;

          case ChatStreamEventType.error:
            _error = event.error ?? 'Unknown error occurred';
            _isStreaming = false;
            _streamingText = '';
            break;
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isStreaming = false;
      _streamingText = '';
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Clear generated actions (call after navigation)
  void clearGeneratedActions() {
    _generatedActions = [];
    notifyListeners();
  }

  // ============================================================================
  // TOOL SELECTION
  // ============================================================================

  void setSelectedTools(List<String> tools) {
    _selectedTools = tools;
    notifyListeners();
  }

  void toggleTool(String tool) {
    if (_selectedTools.contains(tool)) {
      _selectedTools = _selectedTools.where((t) => t != tool).toList();
    } else {
      _selectedTools = [..._selectedTools, tool];
    }
    notifyListeners();
  }

  void clearTools() {
    _selectedTools = [];
    notifyListeners();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
