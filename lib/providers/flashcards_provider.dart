import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/deck_service.dart';

/// Sort options for decks
enum DeckSortOption { name, cards, recent, lastSession }

/// Sort direction
enum SortDirection { asc, desc }

/// Provider for managing flashcard decks state
/// Equivalent to state management in React flashcards/page.tsx
class FlashcardsProvider extends ChangeNotifier {
  final DeckService _deckService = DeckService();

  // Deck list state
  List<DeckInfo> _deckInfos = [];
  List<DeckInfo> _filteredDeckInfos = [];
  bool _isLoading = false;
  String? _error;

  // Search and filter state
  String _searchQuery = '';
  DeckSortOption _sortBy = DeckSortOption.recent;
  SortDirection _sortDirection = SortDirection.desc;

  // Study session state
  Deck? _studyingDeck;
  int? _studySessionId;
  List<Flashcard> _availableCards = [];
  String? _nextSessionDate;
  int? _conversationId;
  bool _isStudying = false;

  // Share state
  List<MySharedCode> _mySharedCodes = [];
  ShareCodeInfo? _shareCodeInfo;
  bool _isShareCodeLoading = false;

  // Getters
  List<DeckInfo> get deckInfos => _deckInfos;
  List<DeckInfo> get filteredDeckInfos => _filteredDeckInfos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  DeckSortOption get sortBy => _sortBy;
  SortDirection get sortDirection => _sortDirection;

  Deck? get studyingDeck => _studyingDeck;
  int? get studySessionId => _studySessionId;
  List<Flashcard> get availableCards => _availableCards;
  String? get nextSessionDate => _nextSessionDate;
  int? get conversationId => _conversationId;
  bool get isStudying => _isStudying;

  List<MySharedCode> get mySharedCodes => _mySharedCodes;
  ShareCodeInfo? get shareCodeInfo => _shareCodeInfo;
  bool get isShareCodeLoading => _isShareCodeLoading;

  // ============================================================================
  // DECK OPERATIONS
  // ============================================================================

  /// Fetch all deck infos
  Future<void> fetchDeckInfos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _deckInfos = await _deckService.fetchDeckInfos();
      _applyFiltersAndSort();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Set sort option
  void setSortBy(DeckSortOption option) {
    _sortBy = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Toggle sort direction
  void toggleSortDirection() {
    _sortDirection = _sortDirection == SortDirection.asc
        ? SortDirection.desc
        : SortDirection.asc;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Apply filters and sorting to deck list
  void _applyFiltersAndSort() {
    var result = List<DeckInfo>.from(_deckInfos);

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((deckInfo) =>
          deckInfo.name.toLowerCase().contains(query) ||
          (deckInfo.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case DeckSortOption.name:
          comparison = a.name.compareTo(b.name);
        case DeckSortOption.cards:
          comparison = a.flashcardCount.compareTo(b.flashcardCount);
        case DeckSortOption.lastSession:
          final aDate = a.lastSession != null
              ? DateTime.tryParse(a.lastSession!)?.millisecondsSinceEpoch ?? 0
              : 0;
          final bDate = b.lastSession != null
              ? DateTime.tryParse(b.lastSession!)?.millisecondsSinceEpoch ?? 0
              : 0;
          comparison = aDate.compareTo(bDate);
        case DeckSortOption.recent:
          final aDate = DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0;
          final bDate = DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
          comparison = aDate.compareTo(bDate);
      }
      return _sortDirection == SortDirection.asc ? comparison : -comparison;
    });

    _filteredDeckInfos = result;
  }

  /// Create a new deck
  Future<bool> createDeck({
    required String name,
    String? description,
    required List<Flashcard> flashcards,
    int? conversationId,
  }) async {
    try {
      final flashcardsData = flashcards.map((fc) => {
        'question': fc.question,
        'answer': fc.answer,
        'media_url': fc.mediaUrl,
      }).toList();

      final deck = await _deckService.createDeck(
        name: name,
        description: description,
        flashcards: flashcardsData,
        conversationId: conversationId,
      );

      if (deck != null) {
        await fetchDeckInfos();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update existing deck
  Future<bool> updateDeck({
    required int deckId,
    required String name,
    String? description,
    required List<Flashcard> flashcards,
    int? conversationId,
  }) async {
    try {
      final flashcardsData = flashcards.map((fc) => {
        'question': fc.question,
        'answer': fc.answer,
        'media_url': fc.mediaUrl,
      }).toList();

      final success = await _deckService.updateDeck(
        deckId: deckId,
        name: name,
        description: description,
        flashcards: flashcardsData,
        conversationId: conversationId,
      );

      if (success) {
        await fetchDeckInfos();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete deck
  Future<bool> deleteDeck(int deckId) async {
    try {
      final success = await _deckService.deleteDeck(deckId);
      if (success) {
        _deckInfos.removeWhere((d) => d.id == deckId);
        _applyFiltersAndSort();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // STUDY SESSION OPERATIONS
  // ============================================================================

  /// Start studying a deck
  Future<bool> startStudy(DeckInfo deckInfo) async {
    try {
      // Fetch full deck
      final deck = await _deckService.fetchDeck(deckInfo.id);
      if (deck == null) {
        _error = 'Failed to fetch deck';
        notifyListeners();
        return false;
      }

      // Check if deck has flashcards
      if (deck.flashcards.isEmpty) {
        _error = 'This deck has no flashcards';
        notifyListeners();
        return false;
      }

      // Start study session
      final sessionResponse = await _deckService.startStudySession(
        deckId: deck.id,
      );

      if (sessionResponse != null) {
        _studyingDeck = deck;
        _studySessionId = sessionResponse.studySessionId;
        _availableCards = sessionResponse.availableCards;
        _nextSessionDate = sessionResponse.nextSessionDate;
        _conversationId = deck.conversationId;
        _isStudying = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Exit study mode
  void exitStudy() {
    _studyingDeck = null;
    _studySessionId = null;
    _availableCards = [];
    _nextSessionDate = null;
    _conversationId = null;
    _isStudying = false;
    notifyListeners();
  }

  /// Submit study session ratings
  Future<bool> submitRatings(List<Map<String, dynamic>> ratings) async {
    if (_studySessionId == null || _studyingDeck == null) return false;

    try {
      final success = await _deckService.submitBulkRatings(
        sessionId: _studySessionId!,
        deckId: _studyingDeck!.id,
        ratings: ratings,
      );
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Retake hard cards - creates new session and loads hard cards
  Future<bool> retakeHardCards() async {
    if (_studyingDeck == null) return false;

    try {
      final sessionResponse = await _deckService.getHardCards(_studyingDeck!.id);
      if (sessionResponse.availableCards.isNotEmpty) {
        _studySessionId = sessionResponse.studySessionId;
        _availableCards = sessionResponse.availableCards;
        _nextSessionDate = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Retake full session (all cards)
  Future<bool> retakeSession() async {
    if (_studyingDeck == null) return false;

    try {
      final allCards = await _deckService.getRetakeSession(_studyingDeck!.id);
      if (allCards.isNotEmpty) {
        _availableCards = allCards;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // SHARING OPERATIONS
  // ============================================================================

  /// Share a deck
  Future<String?> shareDeck(int deckId) async {
    try {
      final shareCode = await _deckService.shareDeck(deckId);
      if (shareCode != null) {
        await fetchDeckInfos();
      }
      return shareCode;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Get share code info
  Future<void> getShareCodeInfo(String code) async {
    if (code.length != 12) {
      _shareCodeInfo = null;
      notifyListeners();
      return;
    }

    _isShareCodeLoading = true;
    _shareCodeInfo = null;
    notifyListeners();

    try {
      _shareCodeInfo = await _deckService.getShareCodeInfo(code.toUpperCase());
    } catch (e) {
      _shareCodeInfo = null;
    } finally {
      _isShareCodeLoading = false;
      notifyListeners();
    }
  }

/// Add deck by share code
  Future<bool> addDeckByCode(String code) async {
    try {
      // This returns a Map<String, dynamic>, but we just need to know it didn't throw
      await _deckService.addDeckByCode(code);

      // If execution reaches here, it was successful
      _shareCodeInfo = null;
      await fetchDeckInfos();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Fetch user's share codes
  Future<void> fetchMySharedCodes() async {
    try {
      _mySharedCodes = await _deckService.getMySharedCodes();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove shared deck
  Future<bool> removeSharedDeck(int deckId) async {
    try {
      final success = await _deckService.removeSharedDeck(deckId);
      if (success) {
        await fetchDeckInfos();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deactivate share code
  Future<bool> deactivateShareCode(String shareCode) async {
    try {
      final success = await _deckService.deactivateShareCode(shareCode);
      if (success) {
        await fetchMySharedCodes();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear share code info
  void clearShareCodeInfo() {
    _shareCodeInfo = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

