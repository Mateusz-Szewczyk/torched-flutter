import 'dart:ui'; // Required for BackdropFilter (if using anywhere locally)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../services/file_service.dart';
import '../category_dropdown.dart';
import '../common/glass_components.dart';
import 'base_glass_dialog.dart';

/// Manage files dialog
class ManageFilesDialog extends StatefulWidget {
  const ManageFilesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return BaseGlassDialog.show<void>(
      context,
      builder: (context) => const ManageFilesDialog(),
    );
  }

  @override
  State<ManageFilesDialog> createState() => _ManageFilesDialogState();
}

class _ManageFilesDialogState extends State<ManageFilesDialog> with SingleTickerProviderStateMixin {
  final FileService _fileService = FileService();
  List<UploadedFileInfo> _files = [];
  bool _isLoading = true;
  late TabController _tabController;

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final files = await _fileService.fetchFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFileUploaded(List<UploadedFileInfo> newFiles) {
    setState(() {
      _files = [..._files, ...newFiles];
    });
    // If mobile, switch to files tab
    if (MediaQuery.of(context).size.width < 768) {
      _tabController.animateTo(1);
    }
  }

  void _handleFileDeleted(String fileId) {
    setState(() {
      _files = _files.where((f) => f.id != fileId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    Widget desktopLayout = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 350,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _UploadForm(onFileUploaded: _handleFileUploaded),
            )),
        VerticalDivider(width: 1, color: cs.outline.withValues(alpha: 0.1)),
        Expanded(
          child: _FilesList(
            files: _files,
            isLoading: _isLoading,
            onRefresh: _loadFiles,
            onDelete: _handleFileDeleted,
          ),
        ),
      ],
    );

    Widget mobileLayout = Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: cs.onPrimaryContainer,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            padding: const EdgeInsets.all(4),
            tabs: const [
              Tab(text: 'Upload'),
              Tab(text: 'Files'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _UploadForm(onFileUploaded: _handleFileUploaded)),
              _FilesList(
                files: _files,
                isLoading: _isLoading,
                onRefresh: _loadFiles,
                onDelete: _handleFileDeleted,
              ),
            ],
          ),
        ),
      ],
    );

    return BaseGlassDialog(
      title: l10n?.manage_files ?? 'File Manager',
      header: isMobile ? null : null, // Use default or custom header
      maxWidth: 1000,
      maxHeight: 700,
      child: isMobile ? mobileLayout : desktopLayout,
    );
  }
}

class _UploadForm extends StatefulWidget {
  final Function(List<UploadedFileInfo>) onFileUploaded;

  const _UploadForm({required this.onFileUploaded});

  @override
  State<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<_UploadForm> {
  final FileService _fileService = FileService();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
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
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Please select a category');
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
        categoryId: _selectedCategoryId!,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
          _descriptionController.clear();
          // _selectedCategoryId = null; // Keep category selected for multiple uploads
          _isUploading = false;
          _uploadProgress = 0;
          _successMessage = 'Upload complete';
        });

        widget.onFileUploaded(uploadedFiles);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMessage = null);
        });
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = 'Upload failed: $e';
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedFileName != null)
          _buildSelectedFileCard(cs)
        else
          _buildGlassPicker(cs),
        const SizedBox(height: 24),
        // Description field
        GhostTextField(
          controller: _descriptionController,
          hintText: l10n?.enter_file_description ?? 'Describe this content...',
          labelText: l10n?.description ?? 'Description',
          maxLines: 3,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        // Category dropdown - directly without wrapper
        CategoryDropdown(
          selectedCategoryId: _selectedCategoryId,
          onChanged: (categoryId) {
            setState(() => _selectedCategoryId = categoryId);
          },
          isEnabled: !_isUploading,
          showLabel: false,
          hintText: l10n?.category ?? 'Choose category',
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _isUploading ? null : _uploadFile,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shadowColor: cs.primary.withValues(alpha: 0.5),
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _isUploading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Text('${(_uploadProgress * 100).toInt()}%'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined),
                      const SizedBox(width: 8),
                      Text(l10n?.upload_new_file ?? 'Upload to Cloud'),
                    ],
                  ),
          ),
        ),
        if (_isUploading) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
        ],
        if (_error != null) _buildMessage(_error!, true, cs),
        if (_successMessage != null) _buildMessage(_successMessage!, false, cs),
      ],
    );
  }

  Widget _buildGlassPicker(ColorScheme cs) {
    return GlassTile(
      onTap: _pickFile,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: cs.primary.withValues(alpha: 0.2), blurRadius: 20),
              ],
            ),
            child: Icon(Icons.add_rounded, size: 32, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Document',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'PDF, DOCX, MD, TXT',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFileCard(ColorScheme cs) {
    return GlassTile(
      padding: const EdgeInsets.all(16),
      color: cs.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: cs.primary,
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedFileBytes != null)
                  Text(
                    _formatFileSize(_selectedFileBytes!.length),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.error),
            onPressed: () => setState(() {
              _selectedFileName = null;
              _selectedFileBytes = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String msg, bool isError, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassTile(
        padding: const EdgeInsets.all(12),
        color: isError
            ? cs.error.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle,
                color: isError ? cs.error : Colors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(msg,
                    style: TextStyle(
                        color: isError ? cs.error : Colors.green))),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FilesList extends StatefulWidget {
  final List<UploadedFileInfo> files;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(String) onDelete;

  const _FilesList({
    required this.files,
    required this.isLoading,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<_FilesList> createState() => _FilesListState();
}

class _FilesListState extends State<_FilesList> {
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
    final cs = Theme.of(context).colorScheme;

    // Using BaseGlassDialog for delete confirmation?
    // Or just a quick dialog since it's an alert.
    // Let's use showDialog with GlassTile.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassTile(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, size: 48, color: cs.error),
              const SizedBox(height: 16),
              const Text('Delete File?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${file.name}"?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: cs.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _fileService.deleteFile(file.name);
      widget.onDelete(file.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('File deleted'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GhostTextField(
            controller: _searchController,
            hintText: 'Search documents...',
            prefixIcon: Icons.search,
          ),
        ),
        Expanded(
          child: _filteredFiles.isEmpty
              ? _buildEmptyState(cs)
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _filteredFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final file = _filteredFiles[index];
                      return _GlassFileItem(
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

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No files found',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _GlassFileItem extends StatelessWidget {
  final UploadedFileInfo file;
  final VoidCallback onDelete;

  const _GlassFileItem({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              colors: [cs.error.withValues(alpha: 0.5), cs.error]),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: GlassTile(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getFileIcon(file.name),
                  color: cs.onSecondaryContainer, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: cs.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          file.category,
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(file.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
             IconButton(
               icon: Icon(Icons.delete_outline, color: cs.error.withValues(alpha: 0.7)),
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

