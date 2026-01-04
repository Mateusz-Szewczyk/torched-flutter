import 'package:flutter/foundation.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';
import '../services/document_service.dart';

/// Provider for managing workspace state
class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceService _workspaceListService = WorkspaceService();
  final DocumentService _documentService = DocumentService();

  // ===========================================================================
  // WORKSPACE LIST STATE (for left panel)
  // ===========================================================================

  List<WorkspaceModel> _workspaces = [];
  List<WorkspaceModel> get workspaces => _workspaces;

  bool _isLoadingWorkspaces = false;
  bool get isLoadingWorkspaces => _isLoadingWorkspaces;

  bool _hasFetchedWorkspaces = false;
  bool get hasFetchedWorkspaces => _hasFetchedWorkspaces;

  String? _workspacesError;
  String? get workspacesError => _workspacesError;

  /// Fetch all workspaces for the user
  Future<void> fetchWorkspaces({bool force = false}) async {
    if (_isLoadingWorkspaces) return;
    if (_hasFetchedWorkspaces && !force) return;

    _isLoadingWorkspaces = true;
    _workspacesError = null;
    notifyListeners();

    try {
      _workspaces = await _workspaceListService.getWorkspaces();
      _hasFetchedWorkspaces = true;
    } catch (e) {
      _workspacesError = e.toString();
      debugPrint('[WorkspaceProvider] Error fetching workspaces: $e');
    } finally {
      _isLoadingWorkspaces = false;
      notifyListeners();
    }
  }

  /// Add a newly created workspace to the list
  void addWorkspace(WorkspaceModel workspace) {
    _workspaces.insert(0, workspace);
    notifyListeners();
  }

  /// Update a workspace in the list
  void updateWorkspaceInList(WorkspaceModel workspace) {
    final index = _workspaces.indexWhere((w) => w.id == workspace.id);
    if (index != -1) {
      _workspaces[index] = workspace;
      notifyListeners();
    }
  }

  /// Remove a workspace from the list
  void removeWorkspaceFromList(String workspaceId) {
    _workspaces.removeWhere((w) => w.id == workspaceId);
    notifyListeners();
  }

  /// Delete a workspace
  Future<bool> deleteWorkspace(String workspaceId) async {
    try {
      await _workspaceListService.deleteWorkspace(workspaceId);
      removeWorkspaceFromList(workspaceId);
      return true;
    } catch (e) {
      debugPrint('[WorkspaceProvider] Error deleting workspace: $e');
      return false;
    }
  }

  // ===========================================================================
  // DOCUMENTS LIST STATE (for current workspace view)
  // ===========================================================================

  List<WorkspaceDocument> _documents = [];
  List<WorkspaceDocument> get documents => _documents;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _selectedDocumentId;
  String? get selectedDocumentId => _selectedDocumentId;

  WorkspaceDocument? get selectedDocument {
    if (_selectedDocumentId == null) return null;
    return _documents.cast<WorkspaceDocument?>().firstWhere(
          (d) => d?.id == _selectedDocumentId,
          orElse: () => null,
        );
  }

  /// Fetch all user's workspace documents
  Future<void> fetchDocuments({String? categoryId}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final docModels = await _documentService.getDocuments(categoryId: categoryId);
      _documents = docModels.map((dm) => WorkspaceDocument(
        id: dm.id,
        title: dm.title,
        originalFilename: dm.description,
        fileType: null,
        totalLength: dm.totalLength,
        totalSections: 0,
        createdAt: dm.createdAt.toIso8601String(),
      )).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching workspace documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a document
  Future<bool> deleteDocument(String documentId) async {
    try {
      await _documentService.deleteDocument(documentId);

      _documents.removeWhere((d) => d.id == documentId);

      if (_selectedDocumentId == documentId) {
        _selectedDocumentId = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting document: $e');
      notifyListeners();
      return false;
    }
  }

  /// Select a document
  void selectDocument(String? documentId) {
    if (_selectedDocumentId != documentId) {
      _selectedDocumentId = documentId;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Clear all state (on logout)
  void clear() {
    _workspaces = [];
    _hasFetchedWorkspaces = false;
    _documents = [];
    _selectedDocumentId = null;
    _error = null;
    _workspacesError = null;
    _isLoading = false;
    _isLoadingWorkspaces = false;
    notifyListeners();
  }
}

