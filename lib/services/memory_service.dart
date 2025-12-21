import '../services/api_service.dart';

/// Service for managing user memories
/// Communicates with /api/memories endpoints on RAG API
class MemoryService {
  final ApiService _api = ApiService();

  /// Fetch all memories for the current user
  Future<List<Memory>> fetchMemories({int limit = 50}) async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/memories/',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final memoriesJson = data['memories'] as List<dynamic>? ?? [];
        return memoriesJson
            .map((json) => Memory.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch memories: $e');
    }
  }

  /// Create a new memory
  Future<Memory> createMemory({
    required String text,
    double importance = 0.5,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/memories/',
        data: {
          'text': text,
          'importance': importance,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Memory.fromJson(response.data!);
      }
      throw Exception('Failed to create memory');
    } catch (e) {
      throw Exception('Failed to create memory: $e');
    }
  }

  /// Search memories semantically
  Future<List<String>> searchMemories({
    required String query,
    int nResults = 5,
    double minImportance = 0.0,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/memories/search',
        data: {
          'query': query,
          'n_results': nResults,
          'min_importance': minImportance,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final memories = response.data!['memories'] as List<dynamic>? ?? [];
        return memories.map((m) => m.toString()).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to search memories: $e');
    }
  }

  /// Delete a specific memory by ID
  Future<bool> deleteMemory(String memoryId) async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/memories/$memoryId',
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete memory: $e');
    }
  }

  /// Delete all memories for the current user
  Future<bool> deleteAllMemories() async {
    try {
      final response = await _api.ragDelete<Map<String, dynamic>>(
        '/memories/',
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete all memories: $e');
    }
  }

  /// Get memory statistics
  Future<MemoryStats> getStats() async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/memories/stats',
      );

      if (response.statusCode == 200 && response.data != null) {
        return MemoryStats.fromJson(response.data!);
      }
      throw Exception('Failed to get memory stats');
    } catch (e) {
      throw Exception('Failed to get memory stats: $e');
    }
  }
}

/// Memory model
class Memory {
  final String id;
  final String text;
  final double importance;
  final String createdAt;
  final String? lastAccessed;

  Memory({
    required this.id,
    required this.text,
    required this.importance,
    required this.createdAt,
    this.lastAccessed,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt: json['created_at'] as String? ?? '',
      lastAccessed: json['last_accessed'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'importance': importance,
      'created_at': createdAt,
      'last_accessed': lastAccessed,
    };
  }

  /// Get importance level as a human-readable label
  String get importanceLabel {
    if (importance >= 0.7) return 'High';
    if (importance >= 0.3) return 'Medium';
    return 'Low';
  }

  /// Get importance color
  ImportanceLevel get importanceLevel {
    if (importance >= 0.7) return ImportanceLevel.high;
    if (importance >= 0.3) return ImportanceLevel.medium;
    return ImportanceLevel.low;
  }
}

enum ImportanceLevel { low, medium, high }

/// Memory statistics model
class MemoryStats {
  final int totalMemories;
  final double averageImportance;
  final ImportanceDistribution importanceDistribution;

  MemoryStats({
    required this.totalMemories,
    required this.averageImportance,
    required this.importanceDistribution,
  });

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      totalMemories: json['total_memories'] as int? ?? 0,
      averageImportance: (json['average_importance'] as num?)?.toDouble() ?? 0.0,
      importanceDistribution: ImportanceDistribution.fromJson(
        json['importance_distribution'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class ImportanceDistribution {
  final int high;
  final int medium;
  final int low;

  ImportanceDistribution({
    required this.high,
    required this.medium,
    required this.low,
  });

  factory ImportanceDistribution.fromJson(Map<String, dynamic> json) {
    return ImportanceDistribution(
      high: json['high'] as int? ?? 0,
      medium: json['medium'] as int? ?? 0,
      low: json['low'] as int? ?? 0,
    );
  }
}

