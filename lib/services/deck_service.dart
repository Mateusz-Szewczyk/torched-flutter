import '../models/models.dart';
import 'api_service.dart';

/// Service for managing flashcard decks
/// Equivalent to deck-related API calls in React flashcards/page.tsx
class DeckService {
  static final DeckService _instance = DeckService._internal();
  factory DeckService() => _instance;
  DeckService._internal();

  final _api = ApiService();

  // simple in-memory cache for overdue stats to avoid flooding the API when
  // widgets rebuild while scrolling. TTL is short (30s) to keep data fresh.
  final Map<int, _OverdueCacheEntry> _overdueCache = {};
  final Map<int, Future<OverdueStats?>> _overdueInFlight = {};
  final Duration _overdueTtl = const Duration(seconds: 30);

  // ============================================================================
  // DECK CRUD OPERATIONS
  // ============================================================================

  /// Fetch all deck infos (list view)
  Future<List<DeckInfo>> fetchDeckInfos({bool includeShared = true}) async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/decks/',
        queryParameters: {'include_shared': includeShared},
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) => DeckInfo.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch single deck with flashcards
  Future<Deck?> fetchDeck(int deckId) async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/decks/get_deck/$deckId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return Deck.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Create new deck
  Future<Deck?> createDeck({
    required String name,
    String? description,
    required List<Map<String, dynamic>> flashcards,
    int? conversationId,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/decks/',
        data: {
          'name': name,
          'description': description ?? '',
          'flashcards': flashcards,
          'conversation_id': conversationId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          return Deck.fromJson(response.data!);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Update existing deck
  Future<bool> updateDeck({
    required int deckId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> flashcards,
    int? conversationId,
  }) async {
    try {
      final response = await _api.ragPut<Map<String, dynamic>>(
        '/decks/$deckId/',
        data: {
          'name': name,
          'description': description ?? '',
          'flashcards': flashcards,
          'conversation_id': conversationId,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete deck
  Future<bool> deleteDeck(int deckId) async {
    try {
      final response = await _api.ragDelete('/decks/$deckId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // STUDY SESSION OPERATIONS
  // ============================================================================

  /// Start a study session
  Future<StudySessionResponse?> startStudySession({
    required int deckId,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/study_sessions/start',
        data: {
          'deck_id': deckId,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        return StudySessionResponse.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Submit bulk ratings for a study session
  Future<bool> submitBulkRatings({
    required int sessionId,
    required int deckId,
    required List<Map<String, dynamic>> ratings,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/study_sessions/bulk_record',
        data: {
          'session_id': sessionId,
          'deck_id': deckId,
          'ratings': ratings,
        },
      );

      // Backend returns 201 for successful creation
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Get hard cards for retake - returns study session response with session ID
  Future<StudySessionResponse> getHardCards(int deckId) async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/study_sessions/retake_hard_cards',
        queryParameters: {'deck_id': deckId},
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final cards = response.data!
            .map((json) => Flashcard.fromJson(json as Map<String, dynamic>))
            .toList();

        // Extract study_session_id from first card (backend includes it in each card)
        final firstCardJson = response.data!.first as Map<String, dynamic>;
        final sessionId = firstCardJson['study_session_id'] as int?;

        return StudySessionResponse(
          studySessionId: sessionId,
          availableCards: cards,
          nextSessionDate: null,
        );
      }
      return StudySessionResponse(
        studySessionId: null,
        availableCards: [],
        nextSessionDate: null,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all cards for retaking full session
  Future<List<Flashcard>> getRetakeSession(int deckId) async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/study_sessions/retake_session',
        queryParameters: {'deck_id': deckId},
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) => Flashcard.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get overdue statistics for a deck
  Future<OverdueStats?> getOverdueStats(int deckId) async {
    try {
      final now = DateTime.now();
      final cacheEntry = _overdueCache[deckId];
      if (cacheEntry != null && now.difference(cacheEntry.fetchedAt) < _overdueTtl) {
        return cacheEntry.stats;
      }

      // If a request for the same deck is already in-flight, return that future
      if (_overdueInFlight.containsKey(deckId)) {
        return _overdueInFlight[deckId];
      }

      final future = _api.ragGet<Map<String, dynamic>>(
        '/study_sessions/overdue_stats',
        queryParameters: {'deck_id': deckId},
      ).then((response) {
        if (response.statusCode == 200 && response.data != null) {
          final stats = OverdueStats.fromJson(response.data!);
          // store in cache
          _overdueCache[deckId] = _OverdueCacheEntry(stats: stats, fetchedAt: DateTime.now());
          return stats;
        }
        return null;
      }).catchError((e) {
        // swallow and return null; callers should handle null
        return null;
      }).whenComplete(() {
        // remove in-flight marker
        _overdueInFlight.remove(deckId);
      });

      _overdueInFlight[deckId] = future;
      return future;
    } catch (e) {
      rethrow;
    }
  }

  /// Reset stale cards (cards not reviewed for 30+ days)
  Future<ResetStaleCardsResponse?> resetStaleCards({
    required int deckId,
    int daysThreshold = 30,
  }) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/study_sessions/reset_stale_cards?deck_id=$deckId&days_threshold=$daysThreshold',
      );

      if (response.statusCode == 200 && response.data != null) {
        return ResetStaleCardsResponse.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // SHARING OPERATIONS
  // ============================================================================

  /// Share a deck and get share code
  Future<String?> shareDeck(int deckId) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/decks/$deckId/share',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!['share_code'] as String?;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get share code info
  Future<ShareCodeInfo?> getShareCodeInfo(String code) async {
    try {
      final response = await _api.ragGet<Map<String, dynamic>>(
        '/decks/share-info/$code',
      );

      if (response.statusCode == 200 && response.data != null) {
        return ShareCodeInfo.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Add deck by share code
  Future<bool> addDeckByCode(String code) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/decks/add-by-code',
        data: {'code': code.trim().toUpperCase()},
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's share codes
  Future<List<MySharedCode>> getMySharedCodes() async {
    try {
      final response = await _api.ragGet<List<dynamic>>(
        '/decks/my-shared-codes',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) => MySharedCode.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Remove shared deck from library
  Future<bool> removeSharedDeck(int deckId) async {
    try {
      final response = await _api.ragDelete('/decks/shared/$deckId');
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate share code
  Future<bool> deactivateShareCode(String shareCode) async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/decks/shared-code/$shareCode/deactivate',
      );
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // CONVERSATION OPERATIONS
  // ============================================================================

  /// Create a new conversation for a deck
  Future<int?> createConversation() async {
    try {
      final response = await _api.ragPost<Map<String, dynamic>>(
        '/chats/',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          return response.data!['id'] as int?;
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Update deck's conversation ID
  Future<bool> updateDeckConversation(int deckId, int conversationId) async {
    try {
      final response = await _api.ragPatch<Map<String, dynamic>>(
        '/decks/$deckId/conversation',
        data: {'conversation_id': conversationId},
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}

/// Study session response model
class StudySessionResponse {
  final int? studySessionId;
  final List<Flashcard> availableCards;
  final String? nextSessionDate;

  StudySessionResponse({
    this.studySessionId,
    required this.availableCards,
    this.nextSessionDate,
  });

  factory StudySessionResponse.fromJson(Map<String, dynamic> json) {
    final cardsJson = json['available_cards'] as List<dynamic>? ?? [];
    return StudySessionResponse(
      studySessionId: json['study_session_id'] as int?,
      availableCards: cardsJson
          .map((card) => Flashcard.fromJson(card as Map<String, dynamic>))
          .toList(),
      nextSessionDate: json['next_session_date'] as String?,
    );
  }
}

/// Overdue statistics model
class OverdueStats {
  final int totalCards;
  final int overdueCards;
  final int dueToday;
  final OverdueBreakdown overdueBreakdown;

  OverdueStats({
    required this.totalCards,
    required this.overdueCards,
    required this.dueToday,
    required this.overdueBreakdown,
  });

  factory OverdueStats.fromJson(Map<String, dynamic> json) {
    return OverdueStats(
      totalCards: json['total_cards'] as int? ?? 0,
      overdueCards: json['overdue_cards'] as int? ?? 0,
      dueToday: json['due_today'] as int? ?? 0,
      overdueBreakdown: OverdueBreakdown.fromJson(
        json['overdue_breakdown'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Overdue breakdown by severity
class OverdueBreakdown {
  final int slightlyOverdue; // 1-2 days
  final int moderatelyOverdue; // 3-7 days
  final int veryOverdue; // >7 days

  OverdueBreakdown({
    required this.slightlyOverdue,
    required this.moderatelyOverdue,
    required this.veryOverdue,
  });

  factory OverdueBreakdown.fromJson(Map<String, dynamic> json) {
    return OverdueBreakdown(
      slightlyOverdue: json['slightly_overdue'] as int? ?? 0,
      moderatelyOverdue: json['moderately_overdue'] as int? ?? 0,
      veryOverdue: json['very_overdue'] as int? ?? 0,
    );
  }
}

/// Reset stale cards response
class ResetStaleCardsResponse {
  final String message;
  final int resetCount;

  ResetStaleCardsResponse({
    required this.message,
    required this.resetCount,
  });

  factory ResetStaleCardsResponse.fromJson(Map<String, dynamic> json) {
    return ResetStaleCardsResponse(
      message: json['message'] as String? ?? '',
      resetCount: json['reset_count'] as int? ?? 0,
    );
  }
}

class _OverdueCacheEntry {
  final OverdueStats stats;
  final DateTime fetchedAt;
  _OverdueCacheEntry({required this.stats, required this.fetchedAt});
}

