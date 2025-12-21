import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global cache manager using SharedPreferences
/// Handles initialization, cleanup, and provides access to cached data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  static const String _conversationsKey = 'cached_conversations';
  static const String _messagesPrefix = 'cached_messages_';
  static const String _syncMetaPrefix = 'sync_meta_';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('CacheManager: Initialized successfully');
    } catch (e) {
      debugPrint('CacheManager: Initialization failed - $e');
      rethrow;
    }
  }

  /// Get cached conversations as JSON list
  List<Map<String, dynamic>> getCachedConversations() {
    if (_prefs == null) return [];
    final jsonStr = _prefs!.getString(_conversationsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheManager: Failed to parse conversations - $e');
      return [];
    }
  }

  /// Save conversations to cache
  Future<void> setCachedConversations(List<Map<String, dynamic>> conversations) async {
    if (_prefs == null) return;
    await _prefs!.setString(_conversationsKey, jsonEncode(conversations));
    await setLastSyncTime('conversations', DateTime.now());
  }

  /// Get cached messages for a conversation
  List<Map<String, dynamic>> getCachedMessages(int conversationId) {
    if (_prefs == null) return [];
    final jsonStr = _prefs!.getString('$_messagesPrefix$conversationId');
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheManager: Failed to parse messages - $e');
      return [];
    }
  }

  /// Save messages to cache
  Future<void> setCachedMessages(int conversationId, List<Map<String, dynamic>> messages) async {
    if (_prefs == null) return;
    await _prefs!.setString('$_messagesPrefix$conversationId', jsonEncode(messages));
    await setLastSyncTime('messages_$conversationId', DateTime.now());
  }

  /// Delete cached messages for a conversation
  Future<void> deleteCachedMessages(int conversationId) async {
    if (_prefs == null) return;
    await _prefs!.remove('$_messagesPrefix$conversationId');
    await _prefs!.remove('$_syncMetaPrefix messages_$conversationId');
  }

  /// Get last sync timestamp for a specific key
  DateTime? getLastSyncTime(String key) {
    if (_prefs == null) return null;
    final timestamp = _prefs!.getInt('$_syncMetaPrefix$key');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set last sync timestamp for a specific key
  Future<void> setLastSyncTime(String key, DateTime time) async {
    if (_prefs == null) return;
    await _prefs!.setInt('$_syncMetaPrefix$key', time.millisecondsSinceEpoch);
  }

  /// Check if cache is stale (older than TTL)
  bool isCacheStale(String key, Duration ttl) {
    final lastSync = getLastSyncTime(key);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > ttl;
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys().where((k) =>
        k.startsWith(_conversationsKey) ||
        k.startsWith(_messagesPrefix) ||
        k.startsWith(_syncMetaPrefix));

    for (final key in keys) {
      await _prefs!.remove(key);
    }
    debugPrint('CacheManager: All caches cleared');
  }

  /// Clear only conversation-related caches
  Future<void> clearConversations() async {
    if (_prefs == null) return;
    await _prefs!.remove(_conversationsKey);

    final messageKeys = _prefs!.getKeys().where((k) => k.startsWith(_messagesPrefix));
    for (final key in messageKeys) {
      await _prefs!.remove(key);
    }

    await _prefs!.remove('${_syncMetaPrefix}conversations');
    debugPrint('CacheManager: Conversation caches cleared');
  }

  /// Get cache statistics for debugging
  Map<String, int> getStats() {
    if (_prefs == null) return {'conversations': 0, 'messageThreads': 0, 'syncEntries': 0};

    final allKeys = _prefs!.getKeys();
    return {
      'conversations': allKeys.contains(_conversationsKey) ? 1 : 0,
      'messageThreads': allKeys.where((k) => k.startsWith(_messagesPrefix)).length,
      'syncEntries': allKeys.where((k) => k.startsWith(_syncMetaPrefix)).length,
    };
  }
}

