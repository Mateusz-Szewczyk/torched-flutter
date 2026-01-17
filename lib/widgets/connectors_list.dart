import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notion_service.dart';
import '../theme/dimens.dart';
import 'common/glass_components.dart';
import 'dialogs/notion_page_picker_dialog.dart';

/// Widget displaying available connectors (Notion, future: Google Drive, etc.)
class ConnectorsList extends StatefulWidget {
  final String? selectedCategoryId;
  final Function(List<dynamic>)? onFilesImported;

  const ConnectorsList({
    super.key,
    this.selectedCategoryId,
    this.onFilesImported,
  });

  @override
  State<ConnectorsList> createState() => _ConnectorsListState();
}

class _ConnectorsListState extends State<ConnectorsList> {
  final NotionService _notionService = NotionService();
  NotionConnectionStatus? _notionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotionStatus();
  }

  Future<void> _loadNotionStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _notionService.getConnectionStatus();
      if (mounted) {
        setState(() {
          _notionStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notionStatus = NotionConnectionStatus(connected: false);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectNotion() async {
    HapticFeedback.mediumImpact();
    try {
      final authUrl = await _notionService.getAuthorizationUrl();
      if (authUrl.isNotEmpty) {
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  Future<void> _openNotionPicker() async {
    if (_notionStatus == null || !_notionStatus!.connected) return;
    
    HapticFeedback.selectionClick();
    
    final result = await NotionPagePickerDialog.show(
      context,
      categoryId: widget.selectedCategoryId,
    );
    
    if (result != null && widget.onFilesImported != null) {
      widget.onFilesImported!([result]);
      _loadNotionStatus(); // Refresh import count
    }
  }

  Future<void> _disconnectNotion() async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Notion?'),
        content: const Text("Your imported documents will remain, but you won't be able to sync them."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _notionService.disconnect();
        _loadNotionStatus();
      } catch (e) {
        // Ignore errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.integration_instructions_outlined, 
                   size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Import from',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        // Notion connector
        _ConnectorTile(
          icon: _notionIcon,
          name: 'Notion',
          connected: _notionStatus?.connected ?? false,
          subtitle: _getNotionSubtitle(),
          onConnect: _connectNotion,
          onImport: _openNotionPicker,
          onDisconnect: _disconnectNotion,
          importDisabled: !(_notionStatus?.canImport ?? false),
          importDisabledReason: _notionStatus != null && !_notionStatus!.canImport
              ? 'Import limit reached (${_notionStatus!.importCount}/${_notionStatus!.importLimit})'
              : null,
        ),
        
        // Coming soon: other connectors
        const SizedBox(height: 8),
        _ComingSoonTile(
          icon: Icons.cloud_outlined,
          name: 'Google Drive',
        ),
        const SizedBox(height: 8),
        _ComingSoonTile(
          icon: Icons.cloud_queue_outlined,
          name: 'Dropbox',
        ),
      ],
    );
  }

  String _getNotionSubtitle() {
    if (_notionStatus == null) return 'Not connected';
    if (!_notionStatus!.connected) return 'Connect your workspace';
    return '${_notionStatus!.workspaceName ?? "Connected"} • ${_notionStatus!.remainingImports} imports left';
  }

  // Notion logo icon
  Widget get _notionIcon => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Center(
      child: Text(
        'N',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),
  );
}


/// Individual connector tile
class _ConnectorTile extends StatelessWidget {
  final Widget icon;
  final String name;
  final bool connected;
  final String subtitle;
  final VoidCallback onConnect;
  final VoidCallback onImport;
  final VoidCallback onDisconnect;
  final bool importDisabled;
  final String? importDisabledReason;

  const _ConnectorTile({
    required this.icon,
    required this.name,
    required this.connected,
    required this.subtitle,
    required this.onConnect,
    required this.onImport,
    required this.onDisconnect,
    this.importDisabled = false,
    this.importDisabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return GlassTile(
      onTap: connected ? (importDisabled ? null : onImport) : onConnect,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 14),
          
          // Name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (connected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  importDisabled && importDisabledReason != null 
                      ? importDisabledReason! 
                      : subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: importDisabled ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Action button
          if (connected) ...[
            IconButton(
              icon: Icon(Icons.download_outlined, color: cs.primary),
              onPressed: importDisabled ? null : onImport,
              tooltip: 'Import from $name',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant, size: 20),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.link_off, size: 18, color: cs.error),
                      const SizedBox(width: 8),
                      Text('Disconnect', style: TextStyle(color: cs.error)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'disconnect') onDisconnect();
              },
            ),
          ] else ...[
            FilledButton.tonal(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }
}


/// Coming soon placeholder tile
class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String name;

  const _ComingSoonTile({
    required this.icon,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Opacity(
      opacity: 0.5,
      child: GlassTile(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.onSurfaceVariant, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
