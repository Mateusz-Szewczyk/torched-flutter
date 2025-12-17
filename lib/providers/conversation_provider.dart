import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../config/constants.dart';

// Conversation Provider - equivalent to ConversationContext.tsx

class ConversationProvider with ChangeNotifier {
  final _api = ApiService();

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // CONVERSATION MANAGEMENT
  // ============================================================================

  // Load all conversations
  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get<List<dynamic>>(
        '${AppConfig.conversationEndpoint}/history',
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
      final response = await _api.post<Map<String, dynamic>>(
        '${AppConfig.conversationEndpoint}/new',
        data: title != null ? {'title': title} : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        final conversation = Conversation.fromJson(response.data!);
        _conversations.insert(0, conversation);
        _currentConversation = conversation;
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

  // Load specific conversation
  Future<void> loadConversation(int conversationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '${AppConfig.conversationEndpoint}/$conversationId',
      );

      if (response.statusCode == 200 && response.data != null) {
        _currentConversation = Conversation.fromJson(response.data!);
        _messages = _currentConversation?.messages ?? [];
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
    _messages = conversation?.messages ?? [];
    notifyListeners();
  }

  // Set current conversation by ID
  void setCurrentConversationId(int? id) {
    if (id == null) {
      _currentConversation = null;
      _messages = [];
    } else {
      loadConversation(id);
    }
    notifyListeners();
  }

  // Update conversation title
  Future<void> updateConversationTitle(int conversationId, String newTitle) async {
    try {
      final response = await _api.put<Map<String, dynamic>>(
        '${AppConfig.conversationEndpoint}/$conversationId',
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
      final response = await _api.delete(
        '${AppConfig.conversationEndpoint}/$conversationId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from local list
        _conversations.removeWhere((c) => c.id == conversationId);

        // Clear current conversation if it's the one being deleted
        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
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
  // MESSAGE MANAGEMENT
  // ============================================================================

  // Send message
  Future<void> sendMessage(String content, {int? conversationId}) async {
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
      final endpoint = conversationId != null
          ? '${AppConfig.conversationEndpoint}/$conversationId/message'
          : '${AppConfig.conversationEndpoint}/message';

      final response = await _api.post<Map<String, dynamic>>(
        endpoint,
        data: {'message': content},
      );

      if (response.statusCode == 200 && response.data != null) {
        final assistantMessage = Message.fromJson(response.data!);
        _messages.add(assistantMessage);

        // Update current conversation if needed
        if (response.data!['conversation_id'] != null) {
          final convId = response.data!['conversation_id'] as int;
          if (_currentConversation == null || _currentConversation!.id != convId) {
            await loadConversation(convId);
          }
        }

        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = _api.getErrorMessage(e);
      // Remove optimistic user message on error
      _messages.removeLast();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Clear messages
  void clearMessages() {
    _messages = [];
    _currentConversation = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

