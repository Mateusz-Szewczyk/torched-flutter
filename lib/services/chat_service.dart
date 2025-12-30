import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Service for chat-related API operations
class ChatService {
  final ApiService _api = ApiService();

  // ============================================================================
  // CONVERSATION CRUD OPERATIONS
  // ============================================================================

  /// Fetch all conversations for the current user
  Future<List<Conversation>> fetchConversations() async {
    try {
      final response = await _api.ragGet<List<dynamic>>('/chats/');

      if (response.statusCode == 200 && response.data != null) {
        return response.data!.map((json) {
          final map = json as Map<String, dynamic>;
          return Conversation(
            id: map['id'] as int,
            title: map['title'] as String? ?? 'New Conversation',
            createdAt: map['created_at'] as String? ?? '',
            updatedAt: map['updated_at'] as String? ?? '',
            messages: null,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new conversation
  Future<Conversation?> createConversation() async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>('/chats/');

      if (response.statusCode == 200 && response.data != null) {
        return Conversation.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Update conversation title
  Future<bool> updateConversationTitle(int conversationId, String title) async {
    try {
      final response = await _api.ragPatch<Map<String, dynamic>>(
        '/chats/$conversationId',
        data: {'title': title},
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a conversation
  Future<bool> deleteConversation(int conversationId) async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/chats/$conversationId',
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Fetch messages for a conversation
  Future<List<Message>> fetchMessages(int conversationId) async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/chats/$conversationId/messages/',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!.map((json) {
          final map = json as Map<String, dynamic>;
          final metadata = map['metadata'] as String?;

          // Debug log to verify metadata is received
          if (metadata != null && metadata.isNotEmpty) {
            debugPrint('[ChatService] Message has metadata: ${metadata.substring(0, metadata.length.clamp(0, 100))}...');
          }

          return Message(
            role: map['sender'] as String? ?? 'user',
            content: map['text'] as String? ?? '',
            timestamp: map['created_at'] as String?,
            metadata: metadata, // Include metadata from backend
          );
        }).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Save a message to the conversation
  /// Optionally include metadata with steps and actions
  Future<bool> saveMessage({
    required int conversationId,
    required String sender,
    required String text,
    String? metadata,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'sender': sender,
        'text': text,
      };

      // Include metadata if provided
      if (metadata != null && metadata.isNotEmpty) {
        data['metadata'] = metadata;
      }

      final response = await _api.ragPost<Map<String, dynamic>>(
        '/chats/$conversationId/messages/',
        data: data,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // STREAMING QUERY
  // ============================================================================

  /// Send a query and get streaming response
  /// Returns a Stream of response chunks
  Stream<ChatStreamEvent> streamQuery({
    required int conversationId,
    required String query,
    List<String> selectedTools = const [],
  }) async* {
    final storageService = StorageService();
    final token = await storageService.getToken();

    if (token == null || token.isEmpty) {
      yield ChatStreamEvent.error('Not authenticated. Please log in again.');
      return;
    }

    final uri = Uri.parse('${_api.ragBaseUrl}/query/');

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Authorization'] = 'Bearer $token';

    request.body = jsonEncode({
      'conversation_id': conversationId,
      'query': query,
      'selected_tools': selectedTools,
    });

    try {
      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        String errorMessage = 'HTTP error: ${streamedResponse.statusCode}';
        try {
          final errorBody = await streamedResponse.stream.bytesToString();
          final errorJson = jsonDecode(errorBody) as Map<String, dynamic>;
          errorMessage = errorJson['detail'] as String? ?? errorMessage;
        } catch (_) {}

        yield ChatStreamEvent.error(errorMessage);
        client.close();
        return;
      }

      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Parse SSE format (data: {...}\n\n)
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.isEmpty) continue;

          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              if (jsonStr.isEmpty) continue;

              final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
              final eventType = jsonData['type'] as String?;

              // Handle different event types from backend
              switch (eventType) {
                case 'step':
                  yield ChatStreamEvent.step(
                    jsonData['content'] as String? ?? '',
                    jsonData['status'] as String? ?? 'loading',
                  );
                  break;

                case 'chunk':
                  final chunkContent = jsonData['content'] as String? ?? '';
                  yield ChatStreamEvent.chunk(chunkContent, false);
                  break;

                case 'action':
                  // Check specifically for conversation title update
                  final actionType = jsonData['action_type'] as String? ?? '';

                  if (actionType == 'set_conversation_title') {
                    // It's a title update event
                    yield ChatStreamEvent.titleUpdate(
                      jsonData['name'] as String? ?? 'New Conversation',
                    );
                  } else {
                    // It's a standard tool action (flashcards/exams)
                    yield ChatStreamEvent.action(
                      actionType: actionType,
                      actionId: jsonData['id'] as int? ?? 0,
                      actionName: jsonData['name'] as String? ?? '',
                      actionCount: jsonData['count'] as int? ?? 0,
                    );
                  }
                  break;

                case 'done':
                  yield ChatStreamEvent.done();
                  client.close();
                  return;

                case 'error':
                  yield ChatStreamEvent.error(jsonData['content'] as String? ?? 'Unknown error');
                  client.close();
                  return;

                default:
                  // Handle legacy formats or unknown types
                  if (jsonData.containsKey('chunk')) {
                    final chunkText = jsonData['chunk'] as String? ?? '';
                    final isDone = jsonData['done'] as bool? ?? false;
                    yield ChatStreamEvent.chunk(chunkText, isDone);
                    if (isDone) {
                      yield ChatStreamEvent.done();
                      client.close();
                      return;
                    }
                  } else if (jsonData.containsKey('error')) {
                    yield ChatStreamEvent.error(jsonData['error'] as String);
                    client.close();
                    return;
                  }
              }
            } catch (e) {
              debugPrint('SSE parse error: $e');
            }
          }
        }
      }

      // Stream ended naturally
      yield ChatStreamEvent.done();
      client.close();
    } catch (e) {
      yield ChatStreamEvent.error(e.toString());
    }
  }
}

/// Event types for chat streaming
enum ChatStreamEventType {
  chunk,
  step,
  action,
  titleUpdate, // Added new type
  error,
  done
}

class ChatStreamEvent {
  final ChatStreamEventType type;
  final String? chunk;
  final String? content;
  final String? status;
  final String? error;
  final bool isDone;

  // Action-specific fields
  final String? actionType;  // "flashcards" or "exam"
  final int? actionId;       // deck_id or exam_id
  final String? actionName;  // Name of the created set
  final int? actionCount;    // Number of items (flashcards/questions)

  // Title update field
  final String? title;

  ChatStreamEvent._({
    required this.type,
    this.chunk,
    this.content,
    this.status,
    this.error,
    this.isDone = false,
    this.actionType,
    this.actionId,
    this.actionName,
    this.actionCount,
    this.title,
  });

  factory ChatStreamEvent.chunk(String chunk, bool isDone) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.chunk,
      chunk: chunk,
      isDone: isDone,
    );
  }

  factory ChatStreamEvent.step(String content, String status) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.step,
      content: content,
      status: status,
    );
  }

  factory ChatStreamEvent.action({
    required String actionType,
    required int actionId,
    required String actionName,
    required int actionCount,
  }) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.action,
      actionType: actionType,
      actionId: actionId,
      actionName: actionName,
      actionCount: actionCount,
    );
  }

  // New factory for title updates
  factory ChatStreamEvent.titleUpdate(String title) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.titleUpdate,
      title: title,
    );
  }

  factory ChatStreamEvent.error(String error) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.error,
      error: error,
    );
  }

  factory ChatStreamEvent.done() {
    return ChatStreamEvent._(
      type: ChatStreamEventType.done,
      isDone: true,
    );
  }
}