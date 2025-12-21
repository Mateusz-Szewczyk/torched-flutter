import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../cache/cache_manager.dart';

/// Repository pattern for conversations
/// Implements local-first strategy with background sync
class ConversationRepository {
  static final ConversationRepository _instance = ConversationRepository._internal();
  factory ConversationRepository() => _instance;
  ConversationRepository._internal();

  final ChatService _chatService = ChatService();
  final CacheManager _cacheManager = CacheManager();

  // TTL settings
  static const Duration _conversationListTTL = Duration(minutes: 5);

  // Stream controllers for reactive updates
  final _conversationsController = StreamController<List<Conversation>>.broadcast();
  Stream<List<Conversation>> get conversationsStream => _conversationsController.stream;

  // In-memory cache for optimistic UI
  List<Conversation> _cachedConversations = [];

  // ============================================================================
  // CONVERSATION OPERATIONS
  // ============================================================================

  /// Get all conversations - local first, then sync if stale
  Future<List<Conversation>> getConversations({bool forceRefresh = false}) async {
    // 1. Return cached data immediately if available
    if (_cachedConversations.isNotEmpty && !forceRefresh) {
      _conversationsController.add(_cachedConversations);

      // Check if cache is stale
      if (!_cacheManager.isCacheStale('conversations', _conversationListTTL)) {
        return _cachedConversations;
      }
    }

    // 2. Try loading from persistent storage first
    if (_cachedConversations.isEmpty) {
      final stored = _cacheManager.getCachedConversations();
      if (stored.isNotEmpty) {
        _cachedConversations = stored.map((json) => Conversation(
          id: json['id'] as int,
          title: json['title'] as String? ?? 'Untitled',
          createdAt: json['created_at'] as String? ?? '',
          updatedAt: json['updated_at'] as String? ?? '',
          messages: null,
        )).toList();
        _conversationsController.add(_cachedConversations);
      }
    }

    // 3. Fetch from API in background
    try {
      final apiConversations = await _chatService.fetchConversations();

      // 4. Update cache
      _cachedConversations = apiConversations;
      await _cacheManager.setCachedConversations(
        apiConversations.map((c) => {
          'id': c.id,
          'title': c.title,
          'created_at': c.createdAt,
          'updated_at': c.updatedAt,
        }).toList(),
      );

      // 5. Emit fresh data
      _conversationsController.add(_cachedConversations);

      return apiConversations;
    } catch (e) {
      debugPrint('ConversationRepository: API fetch failed - $e');
      // Return cached data on error
      if (_cachedConversations.isNotEmpty) {
        return _cachedConversations;
      }
      rethrow;
    }
  }

  /// Create new conversation with optimistic UI
  Future<Conversation?> createConversation() async {
    try {
      // Create on server
      final serverConv = await _chatService.createConversation();

      if (serverConv != null) {
        // Add to cache
        _cachedConversations.insert(0, serverConv);
        _conversationsController.add(_cachedConversations);
        return serverConv;
      }

      return null;
    } catch (e) {
      debugPrint('ConversationRepository: Create failed - $e');
      rethrow;
    }
  }

  /// Update conversation title with optimistic UI
  Future<bool> updateTitle(int conversationId, String newTitle) async {
    final index = _cachedConversations.indexWhere((c) => c.id == conversationId);
    final oldTitle = index != -1 ? _cachedConversations[index].title : null;

    // 1. Optimistic update
    if (index != -1) {
      _cachedConversations[index] = _cachedConversations[index].copyWith(title: newTitle);
      _conversationsController.add(_cachedConversations);
    }

    try {
      // 2. Update on server
      final success = await _chatService.updateConversationTitle(conversationId, newTitle);

      if (!success && index != -1 && oldTitle != null) {
        // Rollback
        _cachedConversations[index] = _cachedConversations[index].copyWith(title: oldTitle);
        _conversationsController.add(_cachedConversations);
      }

      return success;
    } catch (e) {
      // Rollback on error
      if (index != -1 && oldTitle != null) {
        _cachedConversations[index] = _cachedConversations[index].copyWith(title: oldTitle);
        _conversationsController.add(_cachedConversations);
      }
      rethrow;
    }
  }

  /// Delete conversation with optimistic UI
  Future<bool> deleteConversation(int conversationId) async {
    final index = _cachedConversations.indexWhere((c) => c.id == conversationId);
    final deletedConv = index != -1 ? _cachedConversations[index] : null;

    // 1. Optimistic removal
    if (index != -1) {
      _cachedConversations.removeAt(index);
      _conversationsController.add(_cachedConversations);
    }

    try {
      // 2. Delete on server
      final success = await _chatService.deleteConversation(conversationId);

      if (!success && deletedConv != null) {
        // Rollback
        _cachedConversations.insert(index, deletedConv);
        _conversationsController.add(_cachedConversations);
      }

      return success;
    } catch (e) {
      // Rollback on error
      if (deletedConv != null) {
        _cachedConversations.insert(index, deletedConv);
        _conversationsController.add(_cachedConversations);
      }
      rethrow;
    }
  }

  /// Get messages for conversation
  Future<List<Message>> getMessages(int conversationId) async {
    try {
      return await _chatService.fetchMessages(conversationId);
    } catch (e) {
      debugPrint('ConversationRepository: Messages fetch failed - $e');
      rethrow;
    }
  }

  void dispose() {
    _conversationsController.close();
  }
}

