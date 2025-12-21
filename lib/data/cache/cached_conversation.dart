import 'package:hive/hive.dart';

part 'cached_conversation.g.dart';

/// Cached conversation model for Hive storage
@HiveType(typeId: 0)
class CachedConversation extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String createdAt;

  @HiveField(3)
  String updatedAt;

  @HiveField(4)
  bool isDirty; // Indicates local changes not yet synced

  @HiveField(5)
  bool isDeleted; // Soft delete for optimistic UI

  @HiveField(6)
  int lastSyncedAt; // Timestamp of last successful sync

  CachedConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isDirty = false,
    this.isDeleted = false,
    int? lastSyncedAt,
  }) : lastSyncedAt = lastSyncedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Create from API response
  factory CachedConversation.fromJson(Map<String, dynamic> json) {
    return CachedConversation(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'New Conversation',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      isDirty: false,
      isDeleted: false,
    );
  }

  /// Convert to API-compatible JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create a copy with updated fields
  CachedConversation copyWith({
    int? id,
    String? title,
    String? createdAt,
    String? updatedAt,
    bool? isDirty,
    bool? isDeleted,
    int? lastSyncedAt,
  }) {
    return CachedConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  /// Mark as dirty (needs sync)
  void markDirty() {
    isDirty = true;
    save();
  }

  /// Mark as synced
  void markSynced() {
    isDirty = false;
    lastSyncedAt = DateTime.now().millisecondsSinceEpoch;
    save();
  }

  @override
  String toString() {
    return 'CachedConversation(id: $id, title: $title, isDirty: $isDirty, isDeleted: $isDeleted)';
  }
}

/// Cached message model for Hive storage
@HiveType(typeId: 1)
class CachedMessage extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final int conversationId;

  @HiveField(2)
  final String role; // 'user' or 'bot'

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String? timestamp;

  @HiveField(5)
  bool isDirty;

  @HiveField(6)
  bool isPending; // For optimistic UI - message not yet confirmed

  CachedMessage({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.timestamp,
    this.isDirty = false,
    this.isPending = false,
  });

  factory CachedMessage.fromJson(Map<String, dynamic> json, int conversationId) {
    return CachedMessage(
      id: json['id'] as int?,
      conversationId: conversationId,
      role: json['sender'] as String? ?? json['role'] as String? ?? 'user',
      content: json['text'] as String? ?? json['content'] as String? ?? '',
      timestamp: json['created_at'] as String? ?? json['timestamp'] as String?,
      isDirty: false,
      isPending: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp,
    };
  }

  CachedMessage copyWith({
    int? id,
    int? conversationId,
    String? role,
    String? content,
    String? timestamp,
    bool? isDirty,
    bool? isPending,
  }) {
    return CachedMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isDirty: isDirty ?? this.isDirty,
      isPending: isPending ?? this.isPending,
    );
  }
}

