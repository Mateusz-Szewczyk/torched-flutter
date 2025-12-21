import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../services/file_service.dart';

/// Mobile-first dialog for managing uploaded files
/// Uses bottom sheet on mobile, dialog on desktop
class ManageFilesDialog extends StatefulWidget {
  const ManageFilesDialog({super.key});

  /// Show the dialog - adapts to screen size
  static Future<void> show(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      // Full-screen modal bottom sheet on mobile
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _MobileFilesSheet(),
      );
    } else {
      // Dialog on desktop/tablet
      return showDialog(
        context: context,
        builder: (context) => const _DesktopFilesDialog(),
      );
    }
  }

  @override
  State<ManageFilesDialog> createState() => _ManageFilesDialogState();
}

class _ManageFilesDialogState extends State<ManageFilesDialog> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// =============================================================================
// MOBILE VERSION - Full screen bottom sheet with tabs
// =============================================================================

class _MobileFilesSheet extends StatefulWidget {
  const _MobileFilesSheet();

  @override
  State<_MobileFilesSheet> createState() => _MobileFilesSheetState();
}

class _MobileFilesSheetState extends State<_MobileFilesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FileService _fileService = FileService();

  // State
  List<UploadedFileInfo> _files = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _fileService.fetchFiles();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onFileUploaded(List<UploadedFileInfo> newFiles) {
    setState(() {
      _files = [..._files, ...newFiles];
    });
    // Switch to files tab after upload
    _tabController.animateTo(1);
  }

  void _onFileDeleted(int fileId) {
    setState(() {
      _files = _files.where((f) => f.id != fileId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n?.manage_files ?? 'My Files',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: colorScheme.onPrimaryContainer,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Upload'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Files (${_files.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Upload tab
                _MobileUploadTab(
                  onFileUploaded: _onFileUploaded,
                ),
                // Files tab
                _MobileFilesTab(
                  files: _files,
                  isLoading: _isLoading,
                  error: _error,
                  onRefresh: _loadFiles,
                  onDelete: _onFileDeleted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MOBILE UPLOAD TAB
// =============================================================================

class _MobileUploadTab extends StatefulWidget {
  final Function(List<UploadedFileInfo>) onFileUploaded;

  const _MobileUploadTab({required this.onFileUploaded});

  @override
  State<_MobileUploadTab> createState() => _MobileUploadTabState();
}

class _MobileUploadTabState extends State<_MobileUploadTab> {
  final FileService _fileService = FileService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    HapticFeedback.selectionClick();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Error selecting file: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFileName == null || _selectedFileBytes == null) {
      setState(() => _error = 'Please select a file first');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a file description');
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a category');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
      _successMessage = null;
    });

    try {
      final uploadedFiles = await _fileService.uploadFile(
        fileName: _selectedFileName!,
        fileBytes: _selectedFileBytes!,
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        onProgress: (sent, total) {
          if (total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      HapticFeedback.heavyImpact();
      setState(() {
        _selectedFileName = null;
        _selectedFileBytes = null;
        _descriptionController.clear();
        _categoryController.clear();
        _isUploading = false;
        _uploadProgress = 0;
        _successMessage = 'File uploaded successfully!';
      });

      widget.onFileUploaded(uploadedFiles);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Upload failed: $e';
        _isUploading = false;
        _uploadProgress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File selection area
          if (_selectedFileName != null)
            _buildSelectedFileCard(colorScheme)
          else
            _buildFilePickerButton(colorScheme, l10n),

          const SizedBox(height: 24),

          // Description field
          Text(
            l10n?.file_description ?? 'Description',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: l10n?.enter_file_description ?? 'What is this file about?',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 20),

          // Category field
          Text(
            l10n?.category ?? 'Category',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              hintText: l10n?.enter_category ?? 'e.g., Math, Physics, Notes',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _uploadFile(),
          ),

          const SizedBox(height: 24),

          // Upload button
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isUploading ? null : _uploadFile,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isUploading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Uploading ${(_uploadProgress * 100).toInt()}%'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded),
                        const SizedBox(width: 8),
                        Text(l10n?.upload_new_file ?? 'Upload File'),
                      ],
                    ),
            ),
          ),

          // Progress bar
          if (_isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
              ),
            ),
          ],

          // Messages
          if (_error != null) ...[
            const SizedBox(height: 16),
            _MessageCard(
              message: _error!,
              isError: true,
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            _MessageCard(
              message: _successMessage!,
              isError: false,
            ),
          ],

          // Spacer for keyboard
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildFilePickerButton(ColorScheme colorScheme, AppLocalizations? l10n) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to select a file',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, DOC, DOCX, TXT, MD',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getFileIcon(_selectedFileName!),
              color: colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedFileBytes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(_selectedFileBytes!.length),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.error),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedFileName = null;
                _selectedFileBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.article;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// =============================================================================
// MOBILE FILES TAB
// =============================================================================

class _MobileFilesTab extends StatefulWidget {
  final List<UploadedFileInfo> files;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final Function(int) onDelete;

  const _MobileFilesTab({
    required this.files,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<_MobileFilesTab> createState() => _MobileFilesTabState();
}

class _MobileFilesTabState extends State<_MobileFilesTab> {
  final TextEditingController _searchController = TextEditingController();
  final FileService _fileService = FileService();

  List<UploadedFileInfo> get _filteredFiles {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return widget.files;

    return widget.files.where((file) {
      return file.name.toLowerCase().contains(query) ||
          file.description.toLowerCase().contains(query) ||
          file.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteFile(UploadedFileInfo file) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _DeleteConfirmationSheet(fileName: file.name),
    );

    if (confirmed != true) return;

    try {
      await _fileService.deleteFile(file.name);
      widget.onDelete(file.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${file.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return _buildErrorState(colorScheme);
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search files...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Files list
        Expanded(
          child: _filteredFiles.isEmpty
              ? _buildEmptyState(colorScheme, l10n)
              : RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    widget.onRefresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = _filteredFiles[index];
                      return _MobileFileCard(
                        file: file,
                        onDelete: () => _deleteFile(file),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, AppLocalizations? l10n) {
    final isSearching = _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.folder_off_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? 'No matching files' : 'No files yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term'
                  : 'Upload your first file to get started',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearching) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load files',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MOBILE FILE CARD - Swipeable
// =============================================================================

class _MobileFileCard extends StatelessWidget {
  final UploadedFileInfo file;
  final VoidCallback onDelete;

  const _MobileFileCard({
    required this.file,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (direction) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Could show file details
            },
            onLongPress: onDelete,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // File icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getFileIconColor(file.name).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFileIcon(file.name),
                      color: _getFileIconColor(file.name),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                file.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(file.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (file.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            file.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Swipe hint
                  Icon(
                    Icons.chevron_left,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.article;
    }
  }

  Color _getFileIconColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

// =============================================================================
// DELETE CONFIRMATION SHEET
// =============================================================================

class _DeleteConfirmationSheet extends StatelessWidget {
  final String fileName;

  const _DeleteConfirmationSheet({required this.fileName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Delete File?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$fileName"',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MESSAGE CARD
// =============================================================================

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? colorScheme.errorContainer : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? colorScheme.error.withValues(alpha: 0.5) : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            color: isError ? colorScheme.error : Colors.green.shade600,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? colorScheme.onErrorContainer : Colors.green.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DESKTOP VERSION - Dialog with side-by-side layout
// =============================================================================

class _DesktopFilesDialog extends StatefulWidget {
  const _DesktopFilesDialog();

  @override
  State<_DesktopFilesDialog> createState() => _DesktopFilesDialogState();
}

class _DesktopFilesDialogState extends State<_DesktopFilesDialog> {
  final FileService _fileService = FileService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<UploadedFileInfo> _files = [];
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _successMessage;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _fileService.fetchFiles();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Error selecting file: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFileName == null || _selectedFileBytes == null) {
      setState(() => _error = 'Please select a file first');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a file description');
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a category');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
      _successMessage = null;
    });

    try {
      final uploadedFiles = await _fileService.uploadFile(
        fileName: _selectedFileName!,
        fileBytes: _selectedFileBytes!,
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        onProgress: (sent, total) {
          if (total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      setState(() {
        _files = [..._files, ...uploadedFiles];
        _selectedFileName = null;
        _selectedFileBytes = null;
        _descriptionController.clear();
        _categoryController.clear();
        _isUploading = false;
        _uploadProgress = 0;
        _successMessage = 'File uploaded successfully!';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        _isUploading = false;
        _uploadProgress = 0;
      });
    }
  }

  Future<void> _deleteFile(UploadedFileInfo file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _fileService.deleteFile(file.name);
      setState(() {
        _files = _files.where((f) => f.id != file.id).toList();
        _successMessage = 'File deleted successfully!';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      setState(() => _error = 'Delete failed: $e');
    }
  }

  List<UploadedFileInfo> get _filteredFiles {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _files;

    return _files.where((file) {
      return file.name.toLowerCase().contains(query) ||
          file.description.toLowerCase().contains(query) ||
          file.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 1200 ? 1000 : 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n?.manage_files ?? 'Manage Files',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upload panel (left)
                  SizedBox(
                    width: 380,
                    child: _buildDesktopUploadPanel(colorScheme, l10n),
                  ),
                  VerticalDivider(width: 1, color: colorScheme.outlineVariant),
                  // Files list (right)
                  Expanded(
                    child: _buildDesktopFilesList(colorScheme, l10n),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopUploadPanel(ColorScheme colorScheme, AppLocalizations? l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.upload_new_file ?? 'Upload New File',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // File selection
          if (_selectedFileName != null)
            _buildSelectedFileDesktop(colorScheme)
          else
            _buildDropZoneDesktop(colorScheme),

          const SizedBox(height: 20),

          // Description
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n?.file_description ?? 'Description',
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          // Category
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              labelText: l10n?.category ?? 'Category',
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          // Upload button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isUploading ? null : _uploadFile,
              icon: _isUploading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading
                  ? 'Uploading ${(_uploadProgress * 100).toInt()}%'
                  : l10n?.upload_new_file ?? 'Upload'),
            ),
          ),

          if (_isUploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _uploadProgress),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            _MessageCard(message: _error!, isError: true),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            _MessageCard(message: _successMessage!, isError: false),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZoneDesktop(ColorScheme colorScheme) {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_rounded,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Click to select a file',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, DOC, DOCX, TXT, MD',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileDesktop(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedFileName!,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedFileName = null;
                _selectedFileBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilesList(ColorScheme colorScheme, AppLocalizations? l10n) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search files...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        Divider(height: 1, color: colorScheme.outlineVariant),

        // Files list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_off_outlined,
                              size: 48, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No matching files'
                                : 'No files uploaded yet',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = _filteredFiles[index];
                        return _DesktopFileCard(
                          file: file,
                          onDelete: () => _deleteFile(file),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _DesktopFileCard extends StatelessWidget {
  final UploadedFileInfo file;
  final VoidCallback onDelete;

  const _DesktopFileCard({
    required this.file,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(file.name),
                color: _getFileIconColor(file.name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(file.category, style: theme.textTheme.labelSmall),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(file.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.article;
    }
  }

  Color _getFileIconColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

