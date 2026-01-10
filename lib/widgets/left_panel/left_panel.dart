import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../services/workspace_service.dart' show WorkspaceModel;
import '../../theme/dimens.dart';
import '../dialogs/login_register_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/profile_dialog.dart';
import '../dialogs/manage_files_dialog.dart';
import '../dialogs/base_glass_dialog.dart';
import '../workspace_form_dialog.dart';
import '../profile/subscription_section.dart';
import 'conversation_list.dart';

/// Left navigation panel - equivalent to left-panel/index.tsx
/// Shows navigation items, conversations, and auth-specific content
class LeftPanel extends StatefulWidget {
  final bool isPanelVisible;
  final bool isMobile;
  final VoidCallback togglePanel;

  const LeftPanel({
    super.key,
    required this.isPanelVisible,
    required this.isMobile,
    required this.togglePanel,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  bool _hasFetchedInitially = false;

  @override
  void initState() {
    super.initState();
    _fetchDataOnce();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only fetch once, not on every dependency change
    if (!_hasFetchedInitially) {
      _fetchDataOnce();
    }
  }

  void _fetchDataOnce() {
    if (_hasFetchedInitially) return;
    _hasFetchedInitially = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchSubscriptionIfNeeded();
      _fetchWorkspacesIfNeeded();
    });
  }

  void _fetchSubscriptionIfNeeded() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    if (authProvider.isAuthenticated && subscriptionProvider.stats == null && !subscriptionProvider.isLoading) {
      subscriptionProvider.fetchStats();
    }
  }

  void _fetchWorkspacesIfNeeded() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final workspaceProvider = context.read<WorkspaceProvider>();
    if (authProvider.isAuthenticated && !workspaceProvider.hasFetchedWorkspaces && !workspaceProvider.isLoadingWorkspaces) {
      workspaceProvider.fetchWorkspaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Glassmorphism panel
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            // Subtle gradient background for glass effect
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colorScheme.surface.withValues(alpha: 0.85),
                      colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
                    ]
                  : [
                      colorScheme.surface.withValues(alpha: 0.92),
                      colorScheme.surfaceContainerLow.withValues(alpha: 0.88),
                    ],
            ),
            // Subtle inner glow / border for glass effect
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Panel header
              _buildHeader(context),

              // Main navigation
              Expanded(
                child: IntrinsicHeight(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary navigation
                        _buildPrimaryNavigation(context, isAuthenticated),

                        // Workspaces section (only if authenticated)
                        if (isAuthenticated) ...[
                          const SizedBox(height: AppDimens.gapXL),
                          _buildWorkspacesSection(context),
                        ],

                        // Conversations section (only if authenticated)
                        if (isAuthenticated) ...[
                          const SizedBox(height: AppDimens.gapXL),
                          _buildConversationsSection(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Footer section
              _buildFooter(context, isAuthenticated),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingXL, 
        vertical: AppDimens.paddingL,
      ),
      // No harsh border - use subtle color shift instead
      child: widget.isPanelVisible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo and title
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppDimens.radiusS),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/favicon.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.local_fire_department_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapM),
                      const Text(
                        'TorchED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Header buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Home button - pill style on hover
                    _HeaderIconButton(
                      icon: Icons.home_rounded,
                      tooltip: 'Home',
                      onPressed: () {
                        context.go('/');
                        if (widget.isMobile) widget.togglePanel();
                      },
                    ),

                    // Close button (mobile only)
                    if (widget.isMobile) ...[
                      const SizedBox(width: 4),
                      _HeaderIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onPressed: widget.togglePanel,
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Center(
              // Collapsed view - only Home button
              child: _HeaderIconButton(
                icon: Icons.home_rounded,
                tooltip: 'Home',
                onPressed: () {
                  context.go('/');
                  if (widget.isMobile) widget.togglePanel();
                },
              ),
            ),
    );
  }

  Widget _buildPrimaryNavigation(BuildContext context, bool isAuthenticated) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtle section header
          if (widget.isPanelVisible)
            _SectionHeader(label: 'Navigation'),

          // Show authenticated menu items
          if (isAuthenticated) ...[
            _NavItem(
              icon: Icons.style_rounded,
              label: 'Flashcards',
              route: '/flashcards',
              isPanelVisible: widget.isPanelVisible,
              isMobile: widget.isMobile,
              onTap: () {
                // Navigate and close panel on mobile to avoid manual closing
                context.go('/flashcards');
                if (widget.isMobile) widget.togglePanel();
              },
            ),
            _NavItem(
              icon: Icons.quiz_rounded,
              label: 'Tests',
              route: '/tests',
              isPanelVisible: widget.isPanelVisible,
              isMobile: widget.isMobile,
              onTap: () {
                context.go('/tests');
                if (widget.isMobile) widget.togglePanel();
              },
            ),
            _NavItem(
              icon: Icons.folder_rounded,
              label: 'My Files',
              isPanelVisible: widget.isPanelVisible,
              isMobile: widget.isMobile,
              onTap: () {
                ManageFilesDialog.show(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspacesSection(BuildContext context) {
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final workspaces = workspaceProvider.workspaces;
    final isLoading = workspaceProvider.isLoadingWorkspaces;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPanelVisible) ...[
            // Subtle section header with add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(label: 'Workspaces'),
                _HeaderIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'New workspace',
                  size: AppDimens.iconS,
                  onPressed: () => _showCreateWorkspaceDialog(context),
                ),
              ],
            ),

            // Workspaces list
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(AppDimens.paddingL),
                child: Center(
                  child: SizedBox(
                    width: AppDimens.iconM,
                    height: AppDimens.iconM,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (workspaces.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingXS, 
                  vertical: AppDimens.paddingL,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimens.paddingL),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.workspaces_outline,
                        size: AppDimens.iconL,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppDimens.gapS),
                      Text(
                        'No workspaces yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapM),
                      TextButton.icon(
                        onPressed: () => _showCreateWorkspaceDialog(context),
                        icon: const Icon(Icons.add_rounded, size: AppDimens.iconS),
                        label: const Text('Create workspace'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.paddingL, 
                            vertical: AppDimens.paddingS,
                          ),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workspaces.length,
                itemBuilder: (context, index) {
                  final workspace = workspaces[index];
                  return _WorkspaceItem(
                    workspace: workspace,
                    isPanelVisible: widget.isPanelVisible,
                    isMobile: widget.isMobile,
                    onTap: () {
                      context.go('/workspace/${workspace.id}');
                      if (widget.isMobile) widget.togglePanel();
                    },
                    onDelete: () => _confirmDeleteWorkspace(context, workspace),
                    onEdit: () => _showEditWorkspaceDialog(context, workspace),
                  );
                },
              ),
          ] else
            // Collapsed view - just show icon
            Tooltip(
              message: 'Workspaces',
              child: IconButton(
                icon: const Icon(Icons.workspaces_rounded),
                onPressed: widget.togglePanel,
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateWorkspaceDialog(BuildContext context) async {
    final result = await WorkspaceFormDialog.show(context);

    if (result != null && mounted) {
      context.read<WorkspaceProvider>().addWorkspace(result);
    }
  }

  void _showEditWorkspaceDialog(BuildContext context, WorkspaceModel workspace) async {
    final result = await WorkspaceFormDialog.show(context, workspace: workspace);

    if (result != null && mounted) {
      context.read<WorkspaceProvider>().updateWorkspaceInList(result);
    }
  }

  void _confirmDeleteWorkspace(BuildContext context, WorkspaceModel workspace) {
    GlassConfirmationDialog.show(
      context,
      title: 'Delete Workspace',
      content: 'Are you sure you want to delete "${workspace.name}"? This will also delete all conversations within it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        final success = await context.read<WorkspaceProvider>().deleteWorkspace(workspace.id);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete workspace'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Widget _buildConversationsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPanelVisible) ...[
            _SectionHeader(label: 'Conversations'),
            ConversationList(
              onConversationClick: (id) {
                // Use deep linking for better UX and URL sharing
                context.read<ConversationProvider>().setCurrentConversation(id);
                context.go('/chat/$id');

                // Close panel on mobile after selection
                if (widget.isMobile) {
                  widget.togglePanel();
                }
              },
            ),
          ] else
            // Collapsed view - just show icon
            Tooltip(
              message: 'Conversations',
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_rounded),
                onPressed: () {
                  widget.togglePanel();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isAuthenticated) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mobile-first: use SafeArea to respect system UI
    return SafeArea(
      top: false,
      child: Container(
        // Glass card effect for footer
        margin: const EdgeInsets.all(AppDimens.paddingM),
        padding: const EdgeInsets.all(AppDimens.paddingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ]
                : [
                    colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ],
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusL),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subscription Info
            if (isAuthenticated && widget.isPanelVisible)
              _SubscriptionInfo(
                isPanelVisible: widget.isPanelVisible,
                isMobile: widget.isMobile,
              ),

            if (isAuthenticated && widget.isPanelVisible)
              const SizedBox(height: AppDimens.gapM),

            // Profile / Login button
            if (isAuthenticated)
              _NavItem(
                icon: Icons.person_rounded,
                label: 'My Profile',
                isPanelVisible: widget.isPanelVisible,
                isMobile: widget.isMobile,
                onTap: () {
                  showProfileDialog(context);
                  if (widget.isMobile) widget.togglePanel();
                },
              )
            else
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Login / Register',
                isPanelVisible: widget.isPanelVisible,
                isMobile: widget.isMobile,
                variant: _NavItemVariant.filled,
                onTap: () {
                  LoginRegisterDialog.show(context);
                  if (widget.isMobile) widget.togglePanel();
                },
              ),

            const SizedBox(height: 4),

            // Settings button
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isPanelVisible: widget.isPanelVisible,
              isMobile: widget.isMobile,
              onTap: () {
                showSettingsDialog(context);
                if (widget.isMobile) widget.togglePanel();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

/// Subtle section header with letter-spacing
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Modern icon button with hover effect
class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 20,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppDimens.paddingS),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.radiusS),
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: _isHovered
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// Workspace item widget
class _WorkspaceItem extends StatefulWidget {
  final WorkspaceModel workspace;
  final bool isPanelVisible;
  final bool isMobile;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _WorkspaceItem({
    required this.workspace,
    required this.isPanelVisible,
    required this.isMobile,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_WorkspaceItem> createState() => _WorkspaceItemState();
}

class _WorkspaceItemState extends State<_WorkspaceItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.isPanelVisible) {
      return Tooltip(
        message: widget.workspace.name,
        child: IconButton(
          icon: const Icon(Icons.folder_rounded, size: 20),
          onPressed: widget.onTap,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 12 : 10,
              vertical: widget.isMobile ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.5 : 0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _isHovered
                  ? Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.1),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Workspace icon with gradient
                Container(
                  width: widget.isMobile ? 36 : 32,
                  height: widget.isMobile ? 36 : 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.tertiary.withOpacity(0.15),
                        colorScheme.tertiary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.tertiary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.workspaces_rounded,
                    size: widget.isMobile ? 18 : 16,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.workspace.name,
                        style: TextStyle(
                          fontSize: widget.isMobile ? 14 : 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.workspace.categories.isNotEmpty)
                        Text(
                          '${widget.workspace.categories.length} ${widget.workspace.categories.length == 1 ? 'category' : 'categories'}',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 11 : 10,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Show menu only on hover (desktop) or always (mobile)
                AnimatedOpacity(
                  opacity: _isHovered || widget.isMobile ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: widget.isMobile ? 20 : 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEdit();
                          break;
                        case 'delete':
                          widget.onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: colorScheme.onSurface),
                            const SizedBox(width: 8),
                            const Text('Edit Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Navigation item widget
enum _NavItemVariant { ghost, filled, outline }

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? route;
  final bool isPanelVisible;
  final bool isActive;
  final _NavItemVariant variant;
  final VoidCallback? onTap;
  final bool isMobile;

  const _NavItem({
    required this.icon,
    required this.label,
    this.route,
    required this.isPanelVisible,
    this.isActive = false,
    this.variant = _NavItemVariant.ghost,
    this.onTap,
    this.isMobile = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isFilledVariant = widget.variant == _NavItemVariant.filled;

    final content = Row(
      mainAxisSize: widget.isPanelVisible ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          widget.isPanelVisible ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Icon(
          widget.icon,
          size: widget.isMobile ? 22 : 20,
          color: isFilledVariant
              ? colorScheme.onPrimary
              : widget.isActive
                  ? colorScheme.tertiary
                  : _isHovered
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
        ),
        if (widget.isPanelVisible) ...[
          SizedBox(width: widget.isMobile ? 14 : 12),
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: widget.isMobile ? 14 : 13,
                color: isFilledVariant
                    ? colorScheme.onPrimary
                    : widget.isActive
                        ? colorScheme.tertiary
                        : _isHovered
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        label: widget.label,
        button: true,
        selected: widget.isActive,
        child: GestureDetector(
          onTap: widget.onTap ?? (widget.route != null ? () => context.go(widget.route!) : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: widget.isPanelVisible
                ? EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 14 : 12,
                    vertical: widget.isMobile ? 12 : 10,
                  )
                : EdgeInsets.all(widget.isMobile ? 10 : 8),
            decoration: BoxDecoration(
              // Filled variant uses tertiary (orange) color
              color: isFilledVariant
                  ? colorScheme.tertiary
                  : widget.isActive
                      ? colorScheme.tertiary.withOpacity(0.12)
                      : _isHovered
                          ? colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.5 : 0.7)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              // Active indicator - left border
              border: widget.isActive && !isFilledVariant
                  ? Border(
                      left: BorderSide(
                        color: colorScheme.tertiary,
                        width: 3,
                      ),
                    )
                  : _isHovered && !isFilledVariant
                      ? Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                          width: 1,
                        )
                      : null,
            ),
            child: content,
          ),
        ),
      ),
    );

    if (!widget.isPanelVisible) {
      return Tooltip(
        message: widget.label,
        child: button,
      );
    }


    return button;
  }
}

Future<void> _showSubscriptionView(BuildContext context) async {
  // Pre-fetch plans if needed, though SubscriptionSection initState also handles it.
  // await context.read<SubscriptionProvider>().fetchPlans();

  if (!context.mounted) return;

  final width = MediaQuery.of(context).size.width;
  final isDesktop = width > 600; // Breakpoint for desktop/tablet

  if (isDesktop) {
    // DESKTOP: Show as a Dialog
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: const _SubscriptionWrapper(
            showCloseButton: true, // Add explicit close button for dialog
          ),
        ),
      ),
    );
  } else {
    // MOBILE: Show as Bottom Sheet with swipe-to-close
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows full height
      useSafeArea: true,
      showDragHandle: true, // Adds the small grey handle indicator
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9, // Opens at 90% height
        minChildSize: 0.5,     // Can be dragged down to 50%
        maxChildSize: 1.0,     // Can be dragged up to full screen
        expand: false,         // Respects content size
        builder: (_, scrollController) => _SubscriptionWrapper(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Wrapper to handle scroll controller injection for the bottom sheet
class _SubscriptionWrapper extends StatelessWidget {
  final ScrollController? scrollController;
  final bool showCloseButton;

  const _SubscriptionWrapper({
    this.scrollController,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showCloseButton)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        Expanded(
          // Pass the scroll controller to SubscriptionSection
          // You need to update SubscriptionSection to accept it
          child: SubscriptionSection(scrollController: scrollController),
        ),
      ],
    );
  }
}

class _SubscriptionInfo extends StatelessWidget {
  final bool isPanelVisible;
  final bool isMobile;

  const _SubscriptionInfo({
    required this.isPanelVisible,
    required this.isMobile,
  });

  bool _isUnlimited(dynamic value) {
    if (value == null) return false;
    if (value is String && (value.toLowerCase() == 'unlimited' || value == '-1')) return true;
    if (value is num && value < 0) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final stats = subscriptionProvider.stats;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (stats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final role = stats.role ?? 'user';
    final limits = stats.limits;
    final usage = stats.usage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role badge row
        Row(
          children: [
            // Futuristic capsule badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: role.toLowerCase() == 'user'
                      ? [
                          colorScheme.surfaceContainerHighest,
                          colorScheme.surfaceContainerHigh,
                        ]
                      : [
                          colorScheme.tertiary.withOpacity(0.2),
                          colorScheme.tertiary.withValues(alpha: 0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: role.toLowerCase() == 'user'
                      ? colorScheme.outline.withOpacity(0.2)
                      : colorScheme.tertiary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                role.toLowerCase() == 'user' ? 'FREE' : role.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: role.toLowerCase() == 'user'
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.tertiary,
                ),
              ),
            ),
            const Spacer(),
            // Upgrade button
            if (role.toLowerCase() == 'user')
              TextButton(
                onPressed: () => _showSubscriptionView(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  backgroundColor: colorScheme.tertiary.withValues(alpha: 0.1),
                  foregroundColor: colorScheme.tertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.tertiary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),

        if (isPanelVisible) ...[
          const SizedBox(height: 12),
          // Ultra-slim usage bars
          _buildUsageBar(
            context,
            'Files',
            usage?['files']?.toString() ?? '0',
            limits?['max_files'],
          ),
          const SizedBox(height: 8),
          _buildUsageBar(
            context,
            'Decks',
            usage?['decks']?.toString() ?? '0',
            limits?['max_decks'],
          ),
          const SizedBox(height: 8),
          _buildUsageBar(
            context,
            'Questions',
            usage?['questions_period']?.toString() ?? '0',
            limits?['max_questions_period'],
          ),
        ],
      ],
    );
  }

  Widget _buildUsageBar(BuildContext context, String label, String usedText, dynamic limit) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final used = int.tryParse(usedText) ?? 0;
    final isUnlimited = _isUnlimited(limit);
    final limitText = isUnlimited ? '∞' : (limit?.toString() ?? '-');
    final progress = isUnlimited ? 0.0 : (limit is num ? (used / (limit as num)).clamp(0.0, 1.0).toDouble() : 0.0);

    // Color based on usage level
    Color progressColor;
    if (progress < 0.5) {
      progressColor = colorScheme.tertiary;
    } else if (progress < 0.8) {
      progressColor = Colors.amber;
    } else {
      progressColor = colorScheme.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '$used / $limitText',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Ultra-slim progress bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    progressColor,
                    progressColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}