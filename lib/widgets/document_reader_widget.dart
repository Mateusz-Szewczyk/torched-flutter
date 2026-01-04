import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_math_fork/flutter_math.dart';
// Ensure this import points to your actual file structure
import '../services/workspace_service.dart';
import '../services/storage_service.dart';

// ==========================================
// MAIN WIDGET
// ==========================================

class DocumentReaderWidget extends StatefulWidget {
  final String documentId;
  final String workspaceId;
  final WorkspaceService workspaceService;
  final Function(String color)? onHighlightColorSelected;
  final VoidCallback? onDocumentDeleted;

  const DocumentReaderWidget({
    super.key,
    required this.documentId,
    required this.workspaceId,
    required this.workspaceService,
    this.onHighlightColorSelected,
    this.onDocumentDeleted,
  });

  @override
  State<DocumentReaderWidget> createState() => _DocumentReaderWidgetState();
}

class _DocumentReaderWidgetState extends State<DocumentReaderWidget> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  bool get wantKeepAlive => true; 

  DocumentMetadata? _document;
  final Map<String, DocumentSection> _sectionsMap = {};
  final List<String> _sectionOrder = [];
  final List<Highlight> _highlights = [];

  // Document images
  final Map<int, List<DocumentImage>> _pageImages = {};
  bool _isLoadingImages = false;
  String? _cachedToken; // Cached auth token for image URLs

  bool _isLoading = true;
  bool _isLoadingMore = false;

  final Map<String, TextSpan> _cachedSpans = {};
  
  // Merged text for cross-section selection
  String _mergedText = '';
  List<_SectionRange> _sectionRanges = [];

  // Track active selection - stores selected text and global offsets
  int? _selectionStart;
  int? _selectionEnd;
  String? _selectedText;

  // Search and page navigation
  bool _isSearchVisible = false;
  List<SearchResult> _searchResults = [];
  int _currentSearchResultIndex = -1;
  bool _isSearching = false;

  // Page navigation
  List<PageInfo> _pages = [];
  int? _currentPage;
  int _totalPages = 0;
  bool _isLoadingPages = false;
  bool _isLoadingPageSections = false;
  int? _pendingPageNavigation;

  // Page tracking - stores first section index for each page
  final Map<int, List<String>> _pageSections = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(DocumentReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _resetAndLoad();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _resetAndLoad() {
    setState(() {
      _isLoading = true;
      _document = null;
      _sectionsMap.clear();
      _sectionOrder.clear();
      _highlights.clear();
      _cachedSpans.clear();
      _pageImages.clear();
      _isLoadingImages = false;
      _isLoadingMore = false;
      _isLoadingMoreDebounced = false;
      _isLoadingPageSections = false;
      _pendingPageNavigation = null;
      _mergedText = '';
      _sectionRanges = [];
      _selectionStart = null;
      _selectionEnd = null;
      _selectedText = null;
      _searchResults = [];
      _currentSearchResultIndex = -1;
      _searchController.clear();
      _pages = [];
      _currentPage = null;
      _totalPages = 0;
      _pageSections.clear();
      _pagesBeingLoaded.clear();
      _lastScrollUpdate = null;
    });
    // Jump to top
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Cache the auth token first - required for image loading
      final storageService = StorageService();
      _cachedToken = await storageService.getToken();

      // Parallel fetch for metadata, first sections, and pages
      final doc = await widget.workspaceService.getDocument(widget.documentId);
      if (!mounted) return;
      
      setState(() {
        _document = doc;
      });

      // Load pages info
      _loadPages();

      // Load document images in background (token is already cached)
      _loadDocumentImages();

      await _loadMoreSections();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load document: $e');
      }
    }
  }

  /// Load all document images and organize by page
  Future<void> _loadDocumentImages() async {
    if (_isLoadingImages) return;
    _isLoadingImages = true;

    try {
      // Cache the token for image URLs if not already cached
      if (_cachedToken == null || _cachedToken!.isEmpty) {
        final storageService = StorageService();
        _cachedToken = await storageService.getToken();
      }

      final images = await widget.workspaceService.getDocumentImages(widget.documentId);
      if (mounted) {
        setState(() {
          _pageImages.clear();
          for (final image in images) {
            _pageImages.putIfAbsent(image.pageNumber, () => []).add(image);
          }
          // Sort images by position within each page
          for (final pageImages in _pageImages.values) {
            pageImages.sort((a, b) {
              final yCompare = (a.yPosition ?? 0).compareTo(b.yPosition ?? 0);
              if (yCompare != 0) return yCompare;
              return (a.xPosition ?? 0).compareTo(b.xPosition ?? 0);
            });
          }
        });
      }
    } catch (e) {
      // Images are optional, don't fail the document load
      debugPrint('Failed to load images: $e');
    } finally {
      _isLoadingImages = false;
    }
  }

  Future<void> _loadPages() async {
    if (_isLoadingPages) return;

    setState(() => _isLoadingPages = true);

    try {
      final pagesResponse = await widget.workspaceService.getDocumentPages(widget.documentId);
      if (mounted) {
        setState(() {
          _pages = pagesResponse.pages;
          _totalPages = pagesResponse.totalPages;
          _isLoadingPages = false;
          // Set current page based on first visible section
          if (_pages.isNotEmpty) {
            _currentPage = _pages.first.pageNumber;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPages = false);
      }
    }
  }

  Future<void> _loadMoreSections() async {
    if (_isLoadingMore || (_document != null && _sectionOrder.length >= _document!.totalSections)) return;

    setState(() => _isLoadingMore = true);

    try {
      final currentCount = _sectionOrder.length;
      final result = await widget.workspaceService.getSections(
        widget.documentId,
        startSection: currentCount,
        endSection: currentCount + 5,
      );

      if (mounted) {
        setState(() {
          for (var section in result.sections) {
            if (!_sectionsMap.containsKey(section.id)) {
              _sectionsMap[section.id] = section;
              _sectionOrder.add(section.id);

              // Build page-to-sections mapping
              final pageNum = section.sectionMetadata['page_number'] as int? ?? 1;
              _pageSections[pageNum] ??= [];
              if (!_pageSections[pageNum]!.contains(section.id)) {
                _pageSections[pageNum]!.add(section.id);
              }
            }
          }

          final existingIds = _highlights.map((h) => h.id).toSet();
          _highlights.addAll(result.highlights.where((h) => !existingIds.contains(h.id)));

          _cachedSpans.clear(); // Clear cache to apply new highlights if any overlap
          _rebuildMergedText(); // Rebuild merged text for cross-section selection
          _isLoadingMore = false;

          // Update current page based on first section's metadata
          _updateCurrentPageFromSections();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      // Don't show error on lazy load failure to avoid nagging, just log or retry silently
    }
  }

  void _updateCurrentPageFromSections() {
    if (_sectionOrder.isEmpty) return;

    // Only set initial page if we haven't set one yet
    if (_currentPage == null) {
      final firstSectionId = _sectionOrder.first;
      final firstSection = _sectionsMap[firstSectionId];
      if (firstSection != null) {
        final pageNum = firstSection.sectionMetadata['page_number'] as int? ?? 1;
        _currentPage = pageNum;
      }
    }
    // Don't override _currentPage if it's already set - let scroll listener handle updates
  }

  // =============================================================================
  // SEARCH FUNCTIONALITY
  // =============================================================================

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchResultIndex = -1;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await widget.workspaceService.searchDocument(
        documentId: widget.documentId,
        query: query.trim(),
        contextSections: 1,
      );

      if (mounted) {
        setState(() {
          _searchResults = response.results;
          _currentSearchResultIndex = response.results.isNotEmpty ? 0 : -1;
          _isSearching = false;
        });

        // Scroll to first result
        if (_searchResults.isNotEmpty) {
          _scrollToSearchResult(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showError('Search failed: $e');
      }
    }
  }

  void _scrollToSearchResult(int resultIndex) {
    if (resultIndex < 0 || resultIndex >= _searchResults.length) return;
    if (_isLoadingPageSections) return; // Prevent calls during page loading

    final result = _searchResults[resultIndex];
    setState(() => _currentSearchResultIndex = resultIndex);

    // First check if we have sections for the page containing this result
    final existingSections = _sectionOrder.where((sectionId) {
      final section = _sectionsMap[sectionId];
      if (section == null) return false;
      final sectionPage = section.sectionMetadata['page_number'] as int? ?? 1;
      return sectionPage == result.pageNumber;
    }).toList();

    if (existingSections.isNotEmpty) {
      // Find the specific section containing the result
      String? targetSectionId;
      for (final sectionId in existingSections) {
        final section = _sectionsMap[sectionId];
        if (section != null && section.sectionIndex == result.sectionIndex) {
          targetSectionId = sectionId;
          break;
        }
      }

      // Fall back to first section of the page
      targetSectionId ??= existingSections.first;

      final sectionIndex = _sectionOrder.indexOf(targetSectionId);
      if (sectionIndex != -1) {
        const double avgSectionHeight = 300.0;
        final approximateOffset = sectionIndex * avgSectionHeight;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            approximateOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _currentPage = result.pageNumber);
      }
      return;
    }

    // Need to load sections for the page - use pending navigation
    _pendingPageNavigation = result.pageNumber;
    _loadSectionsForPage(result.pageNumber);
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    final nextIndex = (_currentSearchResultIndex + 1) % _searchResults.length;
    _scrollToSearchResult(nextIndex);
  }

  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;
    final prevIndex = (_currentSearchResultIndex - 1 + _searchResults.length) % _searchResults.length;
    _scrollToSearchResult(prevIndex);
  }

  // =============================================================================
  // PAGE NAVIGATION
  // =============================================================================

  // Track which pages are currently being loaded to prevent duplicates
  final Set<int> _pagesBeingLoaded = {};

  Future<void> _loadSectionsForPage(int pageNumber) async {
    // Guard against multiple simultaneous calls for the same page
    if (_isLoadingPageSections || _pagesBeingLoaded.contains(pageNumber)) return;

    _pagesBeingLoaded.add(pageNumber);
    _isLoadingPageSections = true;

    try {
      final result = await widget.workspaceService.getSectionsByPage(
        documentId: widget.documentId,
        pageNumber: pageNumber,
      );

      if (mounted) {
        setState(() {
          for (var section in result.sections) {
            if (!_sectionsMap.containsKey(section.id)) {
              _sectionsMap[section.id] = section;
              // Insert in correct order based on section_index
              final insertIndex = _sectionOrder.indexWhere((id) {
                final s = _sectionsMap[id];
                return s != null && s.sectionIndex > section.sectionIndex;
              });
              if (insertIndex == -1) {
                _sectionOrder.add(section.id);
              } else {
                _sectionOrder.insert(insertIndex, section.id);
              }

              // Build page-to-sections mapping
              final pageNum = section.sectionMetadata['page_number'] as int? ?? 1;
              _pageSections[pageNum] ??= [];
              if (!_pageSections[pageNum]!.contains(section.id)) {
                _pageSections[pageNum]!.add(section.id);
              }
            }
          }

          final existingIds = _highlights.map((h) => h.id).toSet();
          _highlights.addAll(result.highlights.where((h) => !existingIds.contains(h.id)));

          _cachedSpans.clear();
          _rebuildMergedText();
          _currentPage = pageNumber;
        });

        // Handle pending navigation after sections are loaded
        if (_pendingPageNavigation != null) {
          final pendingPage = _pendingPageNavigation!;
          _pendingPageNavigation = null;
          // Schedule navigation for next frame to ensure state is updated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToPageAfterLoad(pendingPage);
            }
          });
        }
      }
    } catch (e) {
      // Error loading sections for page - silently ignore
    } finally {
      if (mounted) {
        _isLoadingPageSections = false;
        _pagesBeingLoaded.remove(pageNumber);
      }
    }
  }

  /// Scrolls to page content after sections have been loaded
  void _scrollToPageAfterLoad(int pageNumber) {
    // Find sections for this page
    final pageSections = _sectionOrder.where((sectionId) {
      final section = _sectionsMap[sectionId];
      if (section == null) return false;
      final sectionPage = section.sectionMetadata['page_number'] as int? ?? 1;
      return sectionPage == pageNumber;
    }).toList();

    if (pageSections.isNotEmpty) {
      final firstSectionIndex = _sectionOrder.indexOf(pageSections.first);
      if (firstSectionIndex != -1) {
        const double avgSectionHeight = 300.0;
        final approximateOffset = firstSectionIndex * avgSectionHeight;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            approximateOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _currentPage = pageNumber);
      }
    }
  }

  void _goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _totalPages) return;
    if (_isLoadingPageSections) return; // Prevent multiple calls during loading

    // First check if we already have sections for this page
    final existingSections = _sectionOrder.where((sectionId) {
      final section = _sectionsMap[sectionId];
      if (section == null) return false;
      final sectionPage = section.sectionMetadata['page_number'] as int? ?? 1;
      return sectionPage == pageNumber;
    }).toList();

    if (existingSections.isNotEmpty) {
      // We have sections for this page - scroll to them directly
      final firstSectionIndex = _sectionOrder.indexOf(existingSections.first);
      if (firstSectionIndex != -1) {
        const double avgSectionHeight = 300.0;
        final approximateOffset = firstSectionIndex * avgSectionHeight;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            approximateOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _currentPage = pageNumber);
      }
      return;
    }

    // Need to load sections for this page
    _pendingPageNavigation = pageNumber;
    _loadSectionsForPage(pageNumber);
  }

  void _showPageSelector() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Go to Page',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '$_totalPages pages',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingPages
                    ? const Center(child: CircularProgressIndicator())
                    : _pages.isEmpty
                        ? Center(
                            child: Text(
                              'No pages found',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: _totalPages,
                            itemBuilder: (context, index) {
                              final pageNum = index + 1;
                              final isCurrentPage = pageNum == _currentPage;
                              final hasContent = _pages.any((p) => p.pageNumber == pageNum);

                              return Material(
                                color: isCurrentPage
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : hasContent
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : Theme.of(context).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _goToPage(pageNum);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Center(
                                    child: Text(
                                      '$pageNum',
                                      style: TextStyle(
                                        fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                                        color: isCurrentPage
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rebuilds the merged text and section ranges for cross-section selection
  /// This must match the structure of _buildAllSectionsText
  void _rebuildMergedText() {
    final buffer = StringBuffer();
    _sectionRanges = [];

    int? lastPageNum;

    for (int i = 0; i < _sectionOrder.length; i++) {
      final sectionId = _sectionOrder[i];
      final section = _sectionsMap[sectionId];
      if (section == null) continue;

      final pageNum = section.sectionMetadata['page_number'] as int? ?? 1;

      // Add page separator indicator (newlines) when page changes
      if (lastPageNum != null && pageNum != lastPageNum) {
        buffer.write('\n\n'); // Page separator space
      }
      lastPageNum = pageNum;

      final startOffset = buffer.length;
      buffer.write(section.contentText);
      final endOffset = buffer.length;

      _sectionRanges.add(_SectionRange(
        sectionId: sectionId,
        globalStart: startOffset,
        globalEnd: endOffset,
      ));

      // Add newlines between sections to match _buildAllSectionsText
      if (i < _sectionOrder.length - 1) {
        buffer.write('\n\n');
      }
    }

    _mergedText = buffer.toString();
  }

  // Debounce for scroll page update
  DateTime? _lastScrollUpdate;
  static const _scrollUpdateDebounce = Duration(milliseconds: 200);

  // Prevent excessive loading calls
  bool _isLoadingMoreDebounced = false;

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Load more sections when approaching end - with debouncing
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoadingMoreDebounced && !_isLoadingMore) {
        _isLoadingMoreDebounced = true;
        _loadMoreSections().then((_) {
          // Reset debounce after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _isLoadingMoreDebounced = false;
          });
        });
      }
    }

    // Debounce page update to prevent excessive calls
    final now = DateTime.now();
    if (_lastScrollUpdate != null &&
        now.difference(_lastScrollUpdate!) < _scrollUpdateDebounce) {
      return;
    }
    _lastScrollUpdate = now;

    // Update current page based on scroll position
    _updateCurrentPageFromScroll();
  }

  /// Updates the current page number based on visible content during scroll
  /// Uses section index to determine which page is currently visible
  void _updateCurrentPageFromScroll() {
    if (_sectionOrder.isEmpty) return;

    // Get scroll position
    final scrollOffset = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Calculate the section index at the middle of the viewport for better accuracy
    final targetOffset = scrollOffset + (viewportHeight / 3);

    // Use estimated section height
    const double avgSectionHeight = 300.0;

    // Estimate which section index we're looking at
    int estimatedIndex = (targetOffset / avgSectionHeight).floor();

    // Clamp to valid range
    estimatedIndex = estimatedIndex.clamp(0, _sectionOrder.length - 1);

    // Get the section at this index
    final sectionId = _sectionOrder[estimatedIndex];
    final section = _sectionsMap[sectionId];

    if (section != null) {
      final pageNum = section.sectionMetadata['page_number'] as int? ?? 1;
      if (_currentPage != pageNum) {
        setState(() {
          _currentPage = pageNum;
        });
      }
    }
  }

  /// Handles selection changes from SelectionArea
  void _handleSelectionChanged(SelectedContent? selection) {
    if (selection == null || selection.plainText.isEmpty) {
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
        _selectedText = null;
      });
      return;
    }

    final selectedText = selection.plainText;

    // Store the selected text for highlight creation
    _selectedText = selectedText;

    // Find the position in merged text
    final normalizedSelected = selectedText.trim();
    if (normalizedSelected.isNotEmpty) {
      int startIndex = _mergedText.indexOf(normalizedSelected);

      // If exact match not found, try finding by chunks
      if (startIndex == -1 && normalizedSelected.length > 20) {
        final firstChunk = normalizedSelected.substring(0, 20);
        startIndex = _mergedText.indexOf(firstChunk);
      }

      if (startIndex != -1) {
        _selectionStart = startIndex;
        _selectionEnd = startIndex + normalizedSelected.length;
      } else {
        // Fallback: just mark that we have a selection
        _selectionStart = 0;
        _selectionEnd = normalizedSelected.length;
      }
    }

    // Trigger rebuild to update color circle states
    setState(() {});
  }

  // --- HIGHLIGHT CREATION ---

  /// Handles highlighting when user selects a color
  /// Supports cross-section highlighting by finding text in each section
  Future<void> _handleHighlightWithColor(String color) async {
    if (_selectedText == null || _selectedText!.isEmpty) {
      _showError('Select text first');
      return;
    }

    final selectedText = _selectedText!;
    if (selectedText.trim().isEmpty) {
      _showError('Invalid selection');
      return;
    }


    // Strategy: Search for the selected text in each section
    // and create highlights where matches are found
    bool foundAny = false;

    // First, try to find exact match in merged text
    int globalStart = _selectionStart ?? -1;
    int globalEnd = _selectionEnd ?? -1;

    if (globalStart >= 0 && globalEnd > globalStart) {
      // Use global offsets to determine which sections to highlight
      for (final range in _sectionRanges) {
        // Check if this section overlaps with global selection
        if (range.globalEnd <= globalStart || range.globalStart >= globalEnd) {
          continue; // No overlap
        }

        // Calculate local offsets within this section
        final localStart = (globalStart - range.globalStart).clamp(0, range.globalEnd - range.globalStart).toInt();
        final localEnd = (globalEnd - range.globalStart).clamp(0, range.globalEnd - range.globalStart).toInt();

        if (localStart < localEnd) {
          await _createHighlightForSection(range.sectionId, localStart.toInt(), localEnd.toInt(), color);
          foundAny = true;
        }
      }
    }

    // Fallback: If global offsets didn't work, search for text directly in sections
    if (!foundAny) {
      final searchText = selectedText.trim();

      for (final range in _sectionRanges) {
        final section = _sectionsMap[range.sectionId];
        if (section == null) continue;

        final sectionText = section.contentText;

        // Check if searchText is contained in this section
        int idx = sectionText.indexOf(searchText);
        if (idx != -1) {
          await _createHighlightForSection(range.sectionId, idx, idx + searchText.length, color);
          foundAny = true;
          break; // Found complete match
        }

        // Check for partial matches at section boundaries
        // Check if end of this section matches start of selected text
        for (int matchLen = (sectionText.length).clamp(1, searchText.length); matchLen >= 10; matchLen--) {
          final sectionSuffix = sectionText.substring(sectionText.length - matchLen);
          if (searchText.startsWith(sectionSuffix)) {
            await _createHighlightForSection(
              range.sectionId,
              sectionText.length - matchLen,
              sectionText.length,
              color
            );
            foundAny = true;
            // Continue to find the rest in next section
            break;
          }
        }
      }
    }

    if (!foundAny) {
      _showError('Could not find selected text in document');
    }

    // Clear selection after highlighting
    setState(() {
      _selectionStart = null;
      _selectionEnd = null;
      _selectedText = null;
      _cachedSpans.clear();
    });
  }

  Future<void> _createHighlightForSection(String sectionId, int start, int end, String color) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_$sectionId';

    final tempHighlight = Highlight(
      id: tempId,
      sectionId: sectionId,
      startOffset: start,
      endOffset: end,
      colorCode: color,
      documentId: widget.documentId,
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _highlights.add(tempHighlight);
      _cachedSpans.remove(sectionId);
    });
    
    // Notify parent about color selection for chat context
    widget.onHighlightColorSelected?.call(color);

    try {
      final created = await widget.workspaceService.createHighlight(
        documentId: widget.documentId,
        sectionId: sectionId,
        startOffset: start,
        endOffset: end,
        colorCode: color,
      );
      
      if (mounted) {
        setState(() {
          _highlights.removeWhere((h) => h.id == tempId);
          _highlights.add(created);
          _cachedSpans.remove(sectionId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _highlights.removeWhere((h) => h.id == tempId);
          _cachedSpans.remove(sectionId);
        });
        _showError('Failed to save highlight');
      }
    }
  }

  // --- HIGHLIGHT DELETION ---

  Future<void> _deleteHighlight(Highlight highlight) async {
    setState(() {
      _highlights.removeWhere((h) => h.id == highlight.id);
      _cachedSpans.remove(highlight.sectionId);
    });

    try {
      await widget.workspaceService.deleteHighlight(highlight.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _highlights.add(highlight);
          _cachedSpans.remove(highlight.sectionId);
        });
        _showError('Failed to delete highlight');
      }
    }
  }
  
  // --- DELETE DOCUMENT ---
  
  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document from the workspace? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await widget.workspaceService.deleteDocument(widget.documentId);
        widget.onDocumentDeleted?.call();
      } catch (e) {
        _showError('Failed to delete document: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showDocumentMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   Icon(Icons.description, size: 48, color: Theme.of(context).colorScheme.primary),
                   const SizedBox(height: 16),
                   Text(_document?.title ?? 'Document', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                   const SizedBox(height: 8),
                   Text('${(_document?.totalLength ?? 0) ~/ 1000}k characters • ${(_document?.totalSections ?? 0)} sections', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File Details'),
              subtitle: Text(_document?.originalFilename ?? 'Unknown filename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Document'),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteDocument();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Material(
      color: colorScheme.surface,
      child: SelectionArea(
        onSelectionChanged: _handleSelectionChanged,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              elevation: 1,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              title: _isSearchVisible
                  ? _buildSearchField(colorScheme)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _document?.title ?? 'Document',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_document != null)
                          Text(
                            '${(_document!.totalLength / 1000).toStringAsFixed(1)}k chars • Page ${_currentPage ?? 1}/$_totalPages',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
              actions: [
                // Search toggle
                IconButton(
                  icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
                  tooltip: _isSearchVisible ? 'Close search' : 'Search in document',
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _searchController.clear();
                        _searchResults = [];
                        _currentSearchResultIndex = -1;
                      } else {
                        _searchFocusNode.requestFocus();
                      }
                    });
                  },
                ),
                // Page selector
                IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: 'Go to page',
                  onPressed: _showPageSelector,
                ),
                // More options
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Document Options',
                  onPressed: _showDocumentMenu,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_isSearchVisible && _searchResults.isNotEmpty ? 96 : 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search results bar (when searching)
                    if (_isSearchVisible && _searchResults.isNotEmpty)
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          border: Border(
                            bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              '${_currentSearchResultIndex + 1} of ${_searchResults.length} matches',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                              tooltip: 'Previous result',
                              onPressed: _previousSearchResult,
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                              tooltip: 'Next result',
                              onPressed: _nextSearchResult,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    // Highlight color bar
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
                        color: colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          Text('Highlight:', style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(width: 12),
                          _buildTopBarColorCircle(context, 'red', Colors.red),
                          _buildTopBarColorCircle(context, 'yellow', Colors.amber),
                          _buildTopBarColorCircle(context, 'green', Colors.green),
                          _buildTopBarColorCircle(context, 'blue', Colors.blue),
                          _buildTopBarColorCircle(context, 'purple', Colors.purple),
                          const Spacer(),
                          // Quick page navigation
                          if (_totalPages > 1)
                            TextButton.icon(
                              onPressed: _showPageSelector,
                              icon: const Icon(Icons.layers, size: 16),
                              label: Text('Page ${_currentPage ?? 1}'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Single RichText containing all sections for seamless selection
                    _buildAllSectionsText(context),
                    // Loading indicator at the bottom
                    if (_isLoadingMore)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    // Bottom padding
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search in document...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        contentPadding: EdgeInsets.zero,
        isDense: true,
        suffixIcon: _isSearching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _currentSearchResultIndex = -1;
                      });
                    },
                  )
                : null,
      ),
      style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
      textInputAction: TextInputAction.search,
      onSubmitted: _performSearch,
      onChanged: (value) {
        // Debounced search as user types
        if (value.length >= 3) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == value && mounted) {
              _performSearch(value);
            }
          });
        }
      },
    );
  }

  // --- HELPERS ---

  /// Builds all sections as a single Text.rich widget for seamless cross-section selection
  /// with visual page separators and images
  Widget _buildAllSectionsText(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<InlineSpan> allSpans = [];
    int? lastPageNum;
    Set<int> pagesWithImagesDisplayed = {};

    for (int i = 0; i < _sectionOrder.length; i++) {
      final sectionId = _sectionOrder[i];
      final section = _sectionsMap[sectionId];
      if (section == null) continue;

      final pageNum = section.sectionMetadata['page_number'] as int? ?? 1;

      // Add page separator when page changes (visual divider that doesn't break selection)
      if (lastPageNum != null && pageNum != lastPageNum) {
        // Show images from the previous page (at the end of it)
        if (_pageImages.containsKey(lastPageNum) && !pagesWithImagesDisplayed.contains(lastPageNum)) {
          allSpans.add(const TextSpan(text: '\n'));
          allSpans.add(_buildPageImagesWidget(lastPageNum));
          pagesWithImagesDisplayed.add(lastPageNum);
        }

        allSpans.add(const TextSpan(text: '\n'));
        allSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: isDark
                          ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Page $pageNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: isDark
                          ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        allSpans.add(const TextSpan(text: '\n'));
      }
      lastPageNum = pageNum;

      // Check if this section contains an algorithm block
      final algorithmWidget = _buildAlgorithmSpanIfPresent(context, section.contentText);
      if (algorithmWidget != null) {
        allSpans.add(algorithmWidget);
      } else {
        // Check if this section contains a table (from metadata or content detection)
        final isTableFromMetadata = section.sectionMetadata['is_table'] == true;
        final tableWidget = isTableFromMetadata
            ? _buildTableSpanIfPresent(context, section.contentText)
            : _buildTableSpanIfPresent(context, section.contentText);

        if (tableWidget != null) {
          // Show table as widget span
          allSpans.add(tableWidget);
        } else {
          // Check if this section contains math content
          final hasMath = section.sectionMetadata['has_math'] == true;
          final mathBlocks = section.sectionMetadata['math_blocks'] as List<dynamic>? ?? [];

        // Debug logging for math content
        if (hasMath) {
          debugPrint('[DocumentReader] Section ${section.id} has_math=true, mathBlocks.length=${mathBlocks.length}');
          if (mathBlocks.isNotEmpty) {
            debugPrint('[DocumentReader] First math block: ${mathBlocks.first}');
          }
        }

        if (hasMath && mathBlocks.isNotEmpty) {
          // Build content with math equations inline
          final mathSpans = _buildMathContentSpans(
            context,
            section.contentText,
            section.baseStyles,
            _highlights.where((h) => h.sectionId == section.id).toList(),
            mathBlocks,
          );
          allSpans.addAll(mathSpans);
        } else {
          // Get cached span for this section (regular text)
          if (!_cachedSpans.containsKey(section.id)) {
            final sectionHighlights = _highlights.where((h) => h.sectionId == section.id).toList();
            _cachedSpans[section.id] = _generateStyledSpans(
              context,
              section.contentText,
              section.baseStyles,
              sectionHighlights,
            );
          }

          // Add section span
          allSpans.add(_cachedSpans[section.id]!);
        }
        }
      }

      // Add paragraph break between sections (except for the last one)
      if (i < _sectionOrder.length - 1) {
        allSpans.add(const TextSpan(text: '\n\n'));
      }
    }

    // Show images from the last page
    if (lastPageNum != null && _pageImages.containsKey(lastPageNum) && !pagesWithImagesDisplayed.contains(lastPageNum)) {
      allSpans.add(const TextSpan(text: '\n'));
      allSpans.add(_buildPageImagesWidget(lastPageNum));
    }

    if (allSpans.isEmpty) {
      return Text(
        'No content loaded yet',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: allSpans),
      style: TextStyle(
        fontSize: MediaQuery.of(context).size.width < 600 ? 15.0 : 18.0,
        height: 1.6,
        fontFamily: 'Roboto',
        color: colorScheme.onSurface,
      ),
      textAlign: TextAlign.left,
    );
  }


  Widget _buildTopBarColorCircle(BuildContext context, String colorName, MaterialColor colorSwatch) {
    final hasSelection = (_selectedText != null && _selectedText!.trim().isNotEmpty) ||
        (_selectionStart != null && _selectionEnd != null && _selectionStart! < _selectionEnd!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: hasSelection ? 'Highlight with $colorName' : 'Select text first',
        child: InkWell(
          onTap: () => _handleHighlightWithColor(colorName),
          borderRadius: BorderRadius.circular(16),
          canRequestFocus: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasSelection ? colorSwatch[100] : colorSwatch[50],
              shape: BoxShape.circle,
              border: Border.all(
                color: hasSelection ? colorSwatch[700]! : colorSwatch[300]!,
                width: hasSelection ? 2.0 : 1.5,
              ),
            ),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colorSwatch[hasSelection ? 500 : 300],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a WidgetSpan containing images for a specific page
  WidgetSpan _buildPageImagesWidget(int pageNumber) {
    final images = _pageImages[pageNumber] ?? [];
    if (images.isEmpty) {
      return const WidgetSpan(child: SizedBox.shrink());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: isMobile ? 12 : 20),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    images.length == 1
                        ? 'Image from Page $pageNumber'
                        : '${images.length} Images from Page $pageNumber',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Display images horizontally when multiple, vertically when single
            if (images.length == 1)
              Center(child: _buildImageThumbnail(images.first))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: images.map((image) => Padding(
                    padding: EdgeInsets.only(right: images.last == image ? 0 : 12),
                    child: _buildImageThumbnailCompact(image),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a compact thumbnail for horizontal display (multiple images)
  Widget _buildImageThumbnailCompact(DocumentImage image) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (_cachedToken == null || _cachedToken!.isEmpty) {
      return Container(
        width: isMobile ? 150 : 200,
        height: isMobile ? 150 : 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final imageUrl = widget.workspaceService.getImageUrlSync(image.id, cachedToken: _cachedToken);

    // Compact size for horizontal display
    double displayWidth = isMobile ? 180 : 250;
    double displayHeight = isMobile ? 180 : 250;

    if (image.width != null && image.height != null && image.width! > 0) {
      final aspectRatio = image.width! / image.height!;
      if (aspectRatio > 1.2) {
        // Wide image
        displayHeight = displayWidth / aspectRatio;
      } else if (aspectRatio < 0.8) {
        // Tall image
        displayWidth = displayHeight * aspectRatio;
      }
      // Ensure minimum size
      displayWidth = displayWidth.clamp(120.0, isMobile ? 200.0 : 300.0);
      displayHeight = displayHeight.clamp(100.0, isMobile ? 200.0 : 300.0);
    }

    return GestureDetector(
      onTap: () => _showImageFullscreen(image, imageUrl),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: displayWidth,
          maxHeight: displayHeight,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: displayWidth,
                height: displayHeight,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    color: colorScheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, color: colorScheme.error, size: 32),
                        const SizedBox(height: 4),
                        Text('Error', style: TextStyle(color: colorScheme.error, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
              // Tap hint overlay
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a thumbnail for a single document image
  Widget _buildImageThumbnail(DocumentImage image) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Don't render image if we don't have a token yet
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      return Container(
        width: isMobile ? screenWidth - 48 : 400,
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final imageUrl = widget.workspaceService.getImageUrlSync(image.id, cachedToken: _cachedToken);

    // Calculate display size - show larger images directly
    double maxDisplayWidth = isMobile ? screenWidth - 48 : 600;
    double displayWidth = maxDisplayWidth;
    double displayHeight = 300;

    if (image.width != null && image.height != null && image.width! > 0) {
      final aspectRatio = image.width! / image.height!;
      if (aspectRatio > 1.5) {
        // Wide image
        displayWidth = maxDisplayWidth;
        displayHeight = displayWidth / aspectRatio;
      } else if (aspectRatio < 0.7) {
        // Tall image - limit height
        displayHeight = isMobile ? 400 : 500;
        displayWidth = displayHeight * aspectRatio;
      } else {
        // Normal aspect ratio
        displayWidth = maxDisplayWidth * 0.9;
        displayHeight = displayWidth / aspectRatio;
      }
      // Clamp values
      displayHeight = displayHeight.clamp(150.0, isMobile ? 450.0 : 600.0);
      displayWidth = displayWidth.clamp(200.0, maxDisplayWidth);
    }

    return GestureDetector(
      onTap: () => _showImageFullscreen(image, imageUrl),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: displayWidth,
          maxHeight: displayHeight,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: displayWidth,
                height: displayHeight,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    color: colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    color: colorScheme.errorContainer,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.onErrorContainer,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Subtle zoom hint in corner
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.zoom_in,
                        size: 14,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tap to enlarge',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows an image in fullscreen mode
  void _showImageFullscreen(DocumentImage image, String imageUrl) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Image with interactive viewer for zoom/pan
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            // Image info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page ${image.pageNumber} • Image ${image.imageIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (image.width != null && image.height != null)
                      Text(
                        '${image.width} × ${image.height} pixels',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    if (image.altText != null && image.altText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          image.altText!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _generateStyledSpans(
    BuildContext context,
    String text,
    List<BaseStyle> baseStyles,
    List<Highlight> highlights
  ) {
    final Set<int> splitPoints = {0, text.length};
    for (var s in baseStyles) {
      splitPoints.add(s.start);
      splitPoints.add(s.end);
    }
    for (var h in highlights) {
      splitPoints.add(h.startOffset);
      splitPoints.add(h.endOffset);
    }

    final sortedPoints = splitPoints.toList()..sort();
    final List<TextSpan> children = [];

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final start = sortedPoints[i];
      final end = sortedPoints[i + 1];
      if (start >= end) continue;

      final segmentText = text.substring(start, end);

      bool isBold = false;
      bool isItalic = false;

      for (var s in baseStyles) {
        if (s.start <= start && s.end >= end) {
          if (s.style == 'bold') isBold = true;
          if (s.style == 'italic') isItalic = true;
        }
      }

      Highlight? activeHighlight;
      for (var h in highlights) {
        if (h.startOffset <= start && h.endOffset >= end) {
          activeHighlight = h;
        }
      }

      final bgColor = activeHighlight != null
          ? _getColorFromCode(activeHighlight.colorCode, Theme.of(context).brightness == Brightness.dark)
          : null;

      children.add(
        TextSpan(
          text: segmentText,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : null,
            backgroundColor: bgColor,
          ),
          recognizer: activeHighlight != null ? (TapGestureRecognizer()
            ..onTap = () => _showHighlightMenu(context, activeHighlight!)) : null,
        ),
      );
    }

    return TextSpan(children: children);
  }

  void _showHighlightMenu(BuildContext context, Highlight highlight) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Annotation', style: Theme.of(context).textTheme.titleMedium),
            ),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: _getColorFromCode(highlight.colorCode, false),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Color: ${highlight.colorCode.toUpperCase()}'),
                ],
               ),
             ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Highlight'),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteHighlight(highlight);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromCode(String code, bool isDark) {
    switch (code) {
      case 'red': return isDark ? Colors.red.shade700.withValues(alpha: 0.5) : Colors.red[100]!;
      case 'green': return isDark ? Colors.green.shade700.withValues(alpha: 0.5) : Colors.green[100]!;
      case 'blue': return isDark ? Colors.blue.shade700.withValues(alpha: 0.5) : Colors.blue[100]!;
      case 'yellow': return isDark ? Colors.yellow.shade700.withValues(alpha: 0.5) : Colors.yellow[100]!;
      case 'purple': return isDark ? Colors.purple.shade700.withValues(alpha: 0.5) : Colors.purple[100]!;
      case 'orange': return isDark ? Colors.orange.shade700.withValues(alpha: 0.5) : Colors.orange[100]!;
      default: return Colors.yellow[100]!;
    }
  }

  /// Detects if text contains tabular data and returns parsed table if found
  /// Supports multiple table formats:
  /// - Pipe-separated (|col1|col2|col3|)
  /// - Tab-separated
  /// - Whitespace-aligned columns (2+ spaces)
  /// - Mixed formats
  _ParsedTable? _detectTable(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return null;

    // Try different detection strategies
    _ParsedTable? table;

    // Strategy 1: Pipe-separated table (Markdown style)
    table = _detectPipeTable(lines);
    if (table != null) return table;

    // Strategy 2: Tab-separated
    table = _detectTabSeparatedTable(lines);
    if (table != null) return table;

    // Strategy 3: Whitespace-aligned columns
    table = _detectSpaceAlignedTable(lines);
    if (table != null) return table;

    return null;
  }

  /// Detects pipe-separated tables (Markdown style: |col1|col2|col3|)
  _ParsedTable? _detectPipeTable(List<String> lines) {
    // Count lines with pipes
    final pipeLinesCount = lines.where((l) => l.contains('|')).length;
    if (pipeLinesCount < 2) return null;

    List<List<String>> rows = [];

    for (final line in lines) {
      if (!line.contains('|')) continue;

      // Skip separator lines (---|----|----)
      if (RegExp(r'^[\s|:-]+$').hasMatch(line)) continue;

      // Split by pipe and clean
      var cells = line.split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (cells.length >= 2) {
        rows.add(cells);
      }
    }

    if (rows.length >= 2) {
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      final normalizedRows = rows.map((row) {
        while (row.length < maxCols) row.add('');
        return row.take(maxCols).toList();
      }).toList();

      return _ParsedTable(
        headers: normalizedRows.first,
        rows: normalizedRows.skip(1).toList(),
      );
    }

    return null;
  }

  /// Detects tab-separated tables
  _ParsedTable? _detectTabSeparatedTable(List<String> lines) {
    final tabLinesCount = lines.where((l) => l.contains('\t')).length;
    if (tabLinesCount < 2) return null;

    List<List<String>> rows = [];
    int? expectedColumns;

    for (final line in lines) {
      if (!line.contains('\t')) continue;

      final cells = line.split('\t').map((c) => c.trim()).toList();

      if (cells.length >= 2) {
        if (expectedColumns == null) {
          expectedColumns = cells.length;
          rows.add(cells);
        } else if (cells.length >= expectedColumns - 1 && cells.length <= expectedColumns + 1) {
          rows.add(cells);
        }
      }
    }

    if (rows.length >= 2 && expectedColumns != null && expectedColumns >= 2) {
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      final normalizedRows = rows.map((row) {
        while (row.length < maxCols) row.add('');
        return row.take(maxCols).toList();
      }).toList();

      return _ParsedTable(
        headers: normalizedRows.first,
        rows: normalizedRows.skip(1).toList(),
      );
    }

    return null;
  }

  /// Detects space-aligned tables (2+ spaces as separator)
  _ParsedTable? _detectSpaceAlignedTable(List<String> lines) {
    List<List<String>> rows = [];
    int? expectedColumns;

    // Filter out very short lines that are unlikely to be table rows
    final validLines = lines.where((l) => l.trim().length >= 10).toList();

    for (final line in validLines) {
      // Split by 2+ spaces (common table separator)
      final cells = line.trim().split(RegExp(r'\s{2,}')).where((c) => c.isNotEmpty).toList();

      if (cells.length >= 2) {
        if (expectedColumns == null) {
          expectedColumns = cells.length;
          rows.add(cells);
        } else if (cells.length >= expectedColumns - 1 && cells.length <= expectedColumns + 1) {
          rows.add(cells);
        }
      }
    }

    // Need at least 2 rows with 2+ columns to consider it a table
    // Also check that we have more than just headers and one row
    if (rows.length >= 2 && expectedColumns != null && expectedColumns >= 2) {
      // Additional validation: check if rows contain some numeric values
      // (typical for data tables)
      int numericCellCount = 0;
      for (final row in rows) {
        for (final cell in row) {
          if (RegExp(r'^[\d.,\-+%()]+$').hasMatch(cell.trim())) {
            numericCellCount++;
          }
        }
      }

      // At least some cells should be numeric or all cells should be short (header-like)
      bool hasNumericData = numericCellCount >= rows.length;
      bool hasShortCells = rows.every((row) => row.every((cell) => cell.length <= 25));

      if (!hasNumericData && !hasShortCells && expectedColumns < 3) {
        return null; // Probably not a table
      }

      // Normalize column count
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      final normalizedRows = rows.map((row) {
        while (row.length < maxCols) {
          row.add('');
        }
        return row.take(maxCols).toList();
      }).toList();

      return _ParsedTable(
        headers: normalizedRows.first,
        rows: normalizedRows.skip(1).toList(),
      );
    }

    return null;
  }

  /// Builds a table widget from parsed table data
  /// Responsive design with horizontal scroll on small screens
  Widget _buildTableWidget(BuildContext context, _ParsedTable table) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Calculate optimal font sizes based on screen
    final headerFontSize = isMobile ? 12.0 : (isTablet ? 13.0 : 14.0);
    final cellFontSize = isMobile ? 11.0 : (isTablet ? 12.0 : 13.0);
    final columnSpacing = isMobile ? 12.0 : (isTablet ? 18.0 : 24.0);
    final horizontalMargin = isMobile ? 10.0 : (isTablet ? 14.0 : 16.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.4)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table indicator header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.primaryContainer.withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.table_chart_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Table • ${table.rows.length} rows × ${table.headers.length} columns',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Table content
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth - 80,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                        : colorScheme.surfaceContainerLow,
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : colorScheme.primaryContainer.withValues(alpha: 0.3);
                    }
                    return null;
                  }),
                  columnSpacing: columnSpacing,
                  horizontalMargin: horizontalMargin,
                  headingRowHeight: isMobile ? 44 : 52,
                  dataRowMinHeight: isMobile ? 40 : 48,
                  dataRowMaxHeight: isMobile ? 80 : 100,
                  dividerThickness: 0.5,
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: headerFontSize,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                  dataTextStyle: TextStyle(
                    fontSize: cellFontSize,
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                  columns: table.headers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final header = entry.value;
                    // First column often has special meaning (method name, etc.)
                    final isFirstColumn = index == 0;

                    return DataColumn(
                      label: Container(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? 120 : 180,
                        ),
                        child: Text(
                          header,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: headerFontSize,
                            color: isFirstColumn
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  rows: table.rows.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;
                    final isEvenRow = rowIndex.isEven;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return isDark
                              ? colorScheme.primary.withValues(alpha: 0.1)
                              : colorScheme.primaryContainer.withValues(alpha: 0.3);
                        }
                        return isEvenRow
                            ? null
                            : (isDark
                                ? colorScheme.surfaceContainer.withValues(alpha: 0.3)
                                : colorScheme.surfaceContainerLowest);
                      }),
                      cells: row.asMap().entries.map((cellEntry) {
                        final cellIndex = cellEntry.key;
                        final cell = cellEntry.value;
                        final isFirstColumn = cellIndex == 0;

                        // Try to detect if cell is a number for alignment
                        final isNumeric = RegExp(r'^[\d.,\-+%]+$').hasMatch(cell.trim());

                        return DataCell(
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 120 : 180,
                            ),
                            child: SelectableText(
                              cell,
                              style: TextStyle(
                                fontSize: cellFontSize,
                                fontWeight: isFirstColumn ? FontWeight.w500 : FontWeight.normal,
                                color: isFirstColumn
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(alpha: 0.85),
                                fontFeatures: isNumeric ? [const FontFeature.tabularFigures()] : null,
                              ),
                              textAlign: isNumeric ? TextAlign.end : TextAlign.start,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Checks if section contains an algorithm/pseudocode block and returns widget or null
  InlineSpan? _buildAlgorithmSpanIfPresent(BuildContext context, String text) {
    final algorithm = _detectAlgorithmBlock(text);
    if (algorithm != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _buildAlgorithmWidget(context, algorithm),
      );
    }
    return null;
  }

  /// Detects if text contains an algorithm/pseudocode block
  /// Returns parsed algorithm content or null
  _ParsedAlgorithm? _detectAlgorithmBlock(String text) {
    // Check for code block markers
    if (text.contains('```algorithm')) {
      final startMarker = text.indexOf('```algorithm');
      final endMarker = text.indexOf('```', startMarker + 12);
      if (endMarker > startMarker) {
        final content = text.substring(startMarker + 12, endMarker).trim();
        return _ParsedAlgorithm(
          title: _extractAlgorithmTitle(content),
          lines: _parseAlgorithmLines(content),
        );
      }
    }

    // Check for "Algorithm X" pattern at the start
    final algorithmMatch = RegExp(r'^Algorithm\s+\d+[^\n]*', caseSensitive: false, multiLine: true).firstMatch(text);
    if (algorithmMatch != null) {
      // Look for algorithm-like structure
      final lines = text.split('\n');
      if (_looksLikeAlgorithm(lines)) {
        return _ParsedAlgorithm(
          title: algorithmMatch.group(0) ?? '',
          lines: _parseAlgorithmLines(text),
        );
      }
    }

    // Check for numbered pseudocode lines (1:, 2:, etc.)
    final numberedLines = RegExp(r'^\d+:\s*', multiLine: true).allMatches(text);
    if (numberedLines.length >= 3) {
      return _ParsedAlgorithm(
        title: '',
        lines: _parseAlgorithmLines(text),
      );
    }

    return null;
  }

  /// Extracts algorithm title from content (first line if it looks like a title)
  String _extractAlgorithmTitle(String content) {
    final lines = content.split('\n');
    if (lines.isNotEmpty) {
      final first = lines.first.trim();
      if (first.toLowerCase().startsWith('algorithm') || first.startsWith('Require:') || first.startsWith('Input:')) {
        return first;
      }
    }
    return '';
  }

  /// Checks if lines look like algorithm content
  bool _looksLikeAlgorithm(List<String> lines) {
    int algorithmIndicators = 0;
    for (final line in lines) {
      final trimmed = line.trim().toLowerCase();
      if (RegExp(r'^\d+:\s*').hasMatch(line.trim())) algorithmIndicators++;
      if (trimmed.startsWith('require:') || trimmed.startsWith('ensure:')) algorithmIndicators++;
      if (trimmed.startsWith('input:') || trimmed.startsWith('output:')) algorithmIndicators++;
      if (trimmed.contains('←') || trimmed.contains('<-')) algorithmIndicators++;
      if (RegExp(r'\b(if|then|else|for|while|return|end)\b').hasMatch(trimmed)) algorithmIndicators++;
    }
    return algorithmIndicators >= 3;
  }

  /// Parses algorithm lines into structured format
  List<_AlgorithmLine> _parseAlgorithmLines(String content) {
    final lines = content.split('\n');
    final result = <_AlgorithmLine>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect line number
      int? lineNumber;
      String content = trimmed;
      final numberMatch = RegExp(r'^(\d+):\s*(.*)').firstMatch(trimmed);
      if (numberMatch != null) {
        lineNumber = int.tryParse(numberMatch.group(1) ?? '');
        content = numberMatch.group(2) ?? '';
      }

      // Detect keywords for syntax highlighting
      bool isKeyword = false;
      bool isComment = false;

      final lowerContent = content.toLowerCase();
      if (lowerContent.startsWith('require:') || lowerContent.startsWith('ensure:') ||
          lowerContent.startsWith('input:') || lowerContent.startsWith('output:')) {
        isKeyword = true;
      }
      if (RegExp(r'^\s*(if|then|else|for|while|return|end|do)\b').hasMatch(lowerContent)) {
        isKeyword = true;
      }
      if (content.contains('⊲') || content.trim().startsWith('//')) {
        isComment = true;
      }

      // Calculate indentation level
      final leadingSpaces = line.length - line.trimLeft().length;
      final indentLevel = (leadingSpaces / 2).floor();

      result.add(_AlgorithmLine(
        lineNumber: lineNumber,
        content: content,
        indentLevel: indentLevel.clamp(0, 5),
        isKeyword: isKeyword,
        isComment: isComment,
      ));
    }

    return result;
  }

  /// Builds a styled widget for algorithm/pseudocode display
  Widget _buildAlgorithmWidget(BuildContext context, _ParsedAlgorithm algorithm) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Algorithm header
          if (algorithm.title.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      algorithm.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Algorithm body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: algorithm.lines.map((line) => _buildAlgorithmLine(context, line, isDark, colorScheme)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single algorithm line with proper styling
  Widget _buildAlgorithmLine(BuildContext context, _AlgorithmLine line, bool isDark, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(
        left: line.indentLevel * 16.0,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number
          if (line.lineNumber != null)
            SizedBox(
              width: 28,
              child: Text(
                '${line.lineNumber}:',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          // Line content
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _buildAlgorithmContentSpans(line, isDark, colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds styled spans for algorithm content with syntax highlighting
  List<TextSpan> _buildAlgorithmContentSpans(_AlgorithmLine line, bool isDark, ColorScheme colorScheme) {
    final content = line.content;
    final spans = <TextSpan>[];

    // Keywords to highlight
    final keywords = ['Require', 'Ensure', 'Input', 'Output', 'if', 'then', 'else', 'for', 'while', 'return', 'end', 'do', 'to', 'in'];

    // Split content and highlight parts
    String remaining = content;

    // Check for comment marker (⊲)
    final commentIndex = remaining.indexOf('⊲');
    String mainPart = remaining;
    String? comment;
    if (commentIndex >= 0) {
      mainPart = remaining.substring(0, commentIndex);
      comment = remaining.substring(commentIndex);
    }

    // Highlight keywords in main part
    final wordPattern = RegExp(r'\b(' + keywords.join('|') + r')\b', caseSensitive: false);
    int lastEnd = 0;

    for (final match in wordPattern.allMatches(mainPart)) {
      // Add text before keyword
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: mainPart.substring(lastEnd, match.start),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
        ));
      }
      // Add keyword
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < mainPart.length) {
      // Check for math symbols and arrows
      final remainingText = mainPart.substring(lastEnd);
      spans.addAll(_highlightMathSymbols(remainingText, colorScheme, isDark));
    }

    // Add comment if present
    if (comment != null) {
      spans.add(TextSpan(
        text: comment,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ));
    }

    return spans;
  }

  /// Highlights math symbols in algorithm text
  List<TextSpan> _highlightMathSymbols(String text, ColorScheme colorScheme, bool isDark) {
    final spans = <TextSpan>[];
    final symbolPattern = RegExp(r'(←|→|⊕|∈|∀|∃|≤|≥|≠|<-|->)');

    int lastEnd = 0;
    for (final match in symbolPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      ));
    }

    return spans;
  }

  /// Checks if section contains table and returns appropriate widget or null
  InlineSpan? _buildTableSpanIfPresent(BuildContext context, String text) {
    final table = _detectTable(text);
    if (table != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _buildTableWidget(context, table),
      );
    }
    return null;;
  }

  /// Builds content spans with embedded math equations
  /// Math blocks contain: {text, latex, type, start, end, confidence}
  List<InlineSpan> _buildMathContentSpans(
    BuildContext context,
    String text,
    List<BaseStyle> baseStyles,
    List<Highlight> highlights,
    List<dynamic> mathBlocks,
  ) {
    final List<InlineSpan> spans = [];
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Debug logging
    debugPrint('[MathRenderer] Processing ${mathBlocks.length} math blocks for text of length ${text.length}');

    // Sort math blocks by start position
    final sortedMathBlocks = <Map<String, dynamic>>[];
    for (final block in mathBlocks) {
      if (block is Map<String, dynamic>) {
        sortedMathBlocks.add(block);
      } else if (block is Map) {
        sortedMathBlocks.add(Map<String, dynamic>.from(block));
      }
    }
    sortedMathBlocks.sort((a, b) => ((a['start'] ?? 0) as int).compareTo((b['start'] ?? 0) as int));

    debugPrint('[MathRenderer] Sorted ${sortedMathBlocks.length} blocks');

    int currentPos = 0;

    for (final mathBlock in sortedMathBlocks) {
      final start = mathBlock['start'] as int? ?? 0;
      final end = mathBlock['end'] as int? ?? 0;
      final latex = mathBlock['latex'] as String? ?? '';
      final mathType = mathBlock['type'] as String? ?? 'inline';

      debugPrint('[MathRenderer] Block: start=$start, end=$end, latex=${latex.substring(0, latex.length.clamp(0, 30))}');

      // Skip invalid blocks
      if (start < currentPos || end <= start || end > text.length) {
        debugPrint('[MathRenderer] Skipping invalid block: start=$start, currentPos=$currentPos, end=$end, textLen=${text.length}');
        continue;
      }

      // Add text before this math block
      if (start > currentPos) {
        final beforeText = text.substring(currentPos, start);
        final beforeSpan = _generateStyledSpansForRange(
          context, beforeText, baseStyles, highlights, currentPos,
        );
        spans.add(beforeSpan);
      }

      // Add math equation widget
      spans.add(_buildMathWidget(context, latex, mathType, isDark, colorScheme));

      currentPos = end;
    }

    // Add remaining text after last math block
    if (currentPos < text.length) {
      final afterText = text.substring(currentPos);
      final afterSpan = _generateStyledSpansForRange(
        context, afterText, baseStyles, highlights, currentPos,
      );
      spans.add(afterSpan);
    }

    return spans;
  }

  /// Generates styled spans for a specific text range
  TextSpan _generateStyledSpansForRange(
    BuildContext context,
    String text,
    List<BaseStyle> baseStyles,
    List<Highlight> highlights,
    int textOffset,
  ) {
    // Adjust style positions relative to the text offset
    final adjustedStyles = baseStyles
        .where((s) => s.start < textOffset + text.length && s.end > textOffset)
        .map((s) => BaseStyle(
              start: (s.start - textOffset).clamp(0, text.length),
              end: (s.end - textOffset).clamp(0, text.length),
              style: s.style,
            ))
        .where((s) => s.start < s.end)
        .toList();

    final adjustedHighlights = highlights
        .where((h) => h.startOffset < textOffset + text.length && h.endOffset > textOffset)
        .map((h) => Highlight(
              id: h.id,
              documentId: h.documentId,
              sectionId: h.sectionId,
              startOffset: (h.startOffset - textOffset).clamp(0, text.length),
              endOffset: (h.endOffset - textOffset).clamp(0, text.length),
              colorCode: h.colorCode,
              annotationText: h.annotationText,
              createdAt: h.createdAt,
            ))
        .where((h) => h.startOffset < h.endOffset)
        .toList();

    return _generateStyledSpans(context, text, adjustedStyles, adjustedHighlights);
  }

  /// Builds a math equation widget
  WidgetSpan _buildMathWidget(
    BuildContext context,
    String latex,
    String mathType,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final isBlock = mathType == 'block';
    final fontSize = isBlock ? 18.0 : 16.0;

    debugPrint('[MathWidget] Rendering LaTeX: $latex (type: $mathType)');

    // Clean up the LaTeX string
    String cleanLatex = latex.trim();
    // Remove surrounding dollar signs if present
    if (cleanLatex.startsWith(r'$') && cleanLatex.endsWith(r'$')) {
      cleanLatex = cleanLatex.substring(1, cleanLatex.length - 1);
    }
    if (cleanLatex.startsWith(r'$$') && cleanLatex.endsWith(r'$$')) {
      cleanLatex = cleanLatex.substring(2, cleanLatex.length - 2);
    }

    Widget mathWidget;

    try {
      mathWidget = Math.tex(
        cleanLatex,
        textStyle: TextStyle(
          fontSize: fontSize,
          color: colorScheme.onSurface,
        ),
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
        onErrorFallback: (err) {
          // Fallback to showing the raw LaTeX when parsing fails
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              cleanLatex,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize - 2,
                color: colorScheme.onSurface,
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Fallback widget if Math.tex throws
      mathWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          cleanLatex,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize - 2,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    if (isBlock) {
      // Block math - display on its own line with padding
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center(child: mathWidget),
          ),
        ),
      );
    } else {
      // Inline math - display inline with text
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: mathWidget,
        ),
      );
    }
  }
}

/// Helper class for parsed table data
class _ParsedTable {
  final List<String> headers;
  final List<List<String>> rows;

  _ParsedTable({required this.headers, required this.rows});
}

/// Helper class to track section ranges in merged text
class _SectionRange {
  final String sectionId;
  final int globalStart;
  final int globalEnd;

  _SectionRange({
    required this.sectionId,
    required this.globalStart,
    required this.globalEnd,
  });
}

/// Represents a parsed algorithm block
class _ParsedAlgorithm {
  final String title;
  final List<_AlgorithmLine> lines;

  _ParsedAlgorithm({
    required this.title,
    required this.lines,
  });
}

/// Represents a single line in an algorithm
class _AlgorithmLine {
  final int? lineNumber;
  final String content;
  final int indentLevel;
  final bool isKeyword;
  final bool isComment;

  _AlgorithmLine({
    this.lineNumber,
    required this.content,
    this.indentLevel = 0,
    this.isKeyword = false,
    this.isComment = false,
  });
}


