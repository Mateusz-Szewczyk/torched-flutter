import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../config/constants.dart';

// Conversation Provider - equivalent to ConversationContext.tsx
// Uses RAG API (localhost:8043) for chat functionality

class ConversationProvider with ChangeNotifier {
  final _api = ApiService();

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  int? _currentConversationId;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  int? get currentConversationId => _currentConversationId;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // CONVERSATION MANAGEMENT (RAG API: /chats/)
  // ============================================================================

  // Load all conversations
  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // RAG API endpoint: GET /chats/
      final response = await _api.ragGet<List<dynamic>>(
        '${AppConfig.chatsEndpoint}/',
      );

      if (response.statusCode == 200 && response.data != null) {
        _conversations = response.data!
            .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
            .toList();
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new conversation
  Future<Conversation?> createConversation({String? title}) async {
    try {
      // RAG API endpoint: POST /chats/
      final response = await _api.ragPost<Map<String, dynamic>>(
        '${AppConfig.chatsEndpoint}/',
        data: title != null ? {'title': title} : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        final conversation = Conversation.fromJson(response.data!);
        _conversations.insert(0, conversation);
        _currentConversation = conversation;
        _currentConversationId = conversation.id;
        _messages = [];
        notifyListeners();
        return conversation;
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
      notifyListeners();
    }
    return null;
  }

  // Set current conversation ID
  void setCurrentConversationId(int? id) {
    _currentConversationId = id;
    if (id != null) {
      loadConversation(id);
    } else {
      _currentConversation = null;
      _messages = [];
    }
    notifyListeners();
  }

  // Load specific conversation with messages
  Future<void> loadConversation(int conversationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // RAG API endpoint: GET /chats/{id}/messages/
      final response = await _api.ragGet<List<dynamic>>(
        '${AppConfig.chatsEndpoint}/$conversationId/messages/',
      );

      if (response.statusCode == 200 && response.data != null) {
        _messages = response.data!
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
        _currentConversationId = conversationId;
        _currentConversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => Conversation(
            id: conversationId,
            title: 'Conversation',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set current conversation
  void setCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    _currentConversationId = conversation?.id;
    _messages = conversation?.messages ?? [];
    notifyListeners();
  }

  // Update conversation title
  Future<void> updateConversationTitle(int conversationId, String newTitle) async {
    try {
      // RAG API endpoint: PUT /chats/{id}/
      final response = await _api.ragPut<Map<String, dynamic>>(
        '${AppConfig.chatsEndpoint}/$conversationId/',
        data: {'title': newTitle},
      );

      if (response.statusCode == 200) {
        // Update in local list
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(title: newTitle);
        }

        // Update current conversation if it's the one being edited
        if (_currentConversation?.id == conversationId) {
          _currentConversation = _currentConversation?.copyWith(title: newTitle);
        }

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
      notifyListeners();
    }
  }

  // Delete conversation
  Future<void> deleteConversation(int conversationId) async {
    try {
      // RAG API endpoint: DELETE /chats/{id}/
      final response = await _api.ragDelete(
        '${AppConfig.chatsEndpoint}/$conversationId/',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from local list
        _conversations.removeWhere((c) => c.id == conversationId);

        // Clear current conversation if it's the one being deleted
        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
          _currentConversationId = null;
          _messages = [];
        }

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
      notifyListeners();
    }
  }

  // ============================================================================
  // MESSAGE MANAGEMENT (RAG API: /chats/{id}/messages/)
  // ============================================================================

  // Send message
  Future<void> sendMessage(String content, {int? conversationId, List<String>? tools}) async {
    final convId = conversationId ?? _currentConversationId;

    if (convId == null) {
      // Create new conversation first
      final newConv = await createConversation();
      if (newConv == null) {
        _errorMessage = 'Failed to create conversation';
        notifyListeners();
        return;
      }
      return sendMessage(content, conversationId: newConv.id, tools: tools);
    }

    _isSending = true;
    _errorMessage = null;

    // Add user message optimistically
    final userMessage = Message(
      role: 'user',
      content: content,
      timestamp: DateTime.now().toIso8601String(),
    );
    _messages.add(userMessage);
    notifyListeners();

    try {
      // RAG API endpoint: POST /chats/{id}/messages/
      final response = await _api.ragPost<Map<String, dynamic>>(
        '${AppConfig.chatsEndpoint}/$convId/messages/',
        data: {
          'content': content,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final assistantMessage = Message.fromJson(response.data!);
        _messages.add(assistantMessage);
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
      // Remove optimistic user message on error
      if (_messages.isNotEmpty) {
        _messages.removeLast();
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Clear messages
  void clearMessages() {
    _messages = [];
    _currentConversation = null;
    _currentConversationId = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

