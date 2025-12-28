import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/subscription_provider.dart';
import '../dialogs/login_register_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/profile_dialog.dart';
import '../dialogs/manage_files_dialog.dart';
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
  @override
  void initState() {
    super.initState();
    _fetchSubscriptionIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchSubscriptionIfNeeded();
  }

  void _fetchSubscriptionIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();
      if (authProvider.isAuthenticated && subscriptionProvider.stats == null && !subscriptionProvider.isLoading) {
        subscriptionProvider.fetchStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;

    // Panel content - MainLayout handles positioning and toggle buttons
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // Panel header
          _buildHeader(context),

          // Main navigation
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary navigation
                  _buildPrimaryNavigation(context, isAuthenticated),

                  // Conversations section (only if authenticated)
                  if (isAuthenticated) ...[
                    const SizedBox(height: 16),
                    _buildConversationsSection(context),
                  ],
                ],
              ),
            ),
          ),

          // Footer section
          _buildFooter(context, isAuthenticated),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(100),
          ),
        ),
      ),
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'T',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TorchED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Header buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Home button
                    Tooltip(
                      message: 'Home',
                      child: IconButton(
                        icon: const Icon(Icons.home_outlined, size: 20),
                        onPressed: () => context.go('/'),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    // Close button (mobile only)
                    if (widget.isMobile)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: widget.togglePanel,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            )
          : Center(
              // Collapsed view - only Home button
              child: Tooltip(
                message: 'Home',
                child: IconButton(
                  icon: const Icon(Icons.home_outlined, size: 20),
                  onPressed: () => context.go('/'),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
    );
  }

  Widget _buildPrimaryNavigation(BuildContext context, bool isAuthenticated) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPanelVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),

          // Show authenticated menu items
          if (isAuthenticated) ...[
            _NavItem(
              icon: Icons.style_outlined,
              label: 'Flashcards',
              route: '/flashcards',
              isPanelVisible: widget.isPanelVisible,
            ),
            _NavItem(
              icon: Icons.quiz_outlined,
              label: 'Tests',
              route: '/tests',
              isPanelVisible: widget.isPanelVisible,
            ),
            _NavItem(
              icon: Icons.folder_outlined,
              label: 'My Files',
              isPanelVisible: widget.isPanelVisible,
              onTap: () {
                ManageFilesDialog.show(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPanelVisible) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'CONVERSATIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
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
                icon: const Icon(Icons.chat_bubble_outline),
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

    // Mobile-first: use SafeArea to respect system UI
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isMobile
              ? colorScheme.surfaceContainerLow
              : null,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withAlpha(100),
            ),
          ),
        ),
        // Mobile-first: consistent padding - equal distance from edges
        padding: EdgeInsets.all(widget.isMobile ? 12 : 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subscription Info
            if (isAuthenticated && widget.isPanelVisible)
              _SubscriptionInfo(
                isPanelVisible: widget.isPanelVisible,
                isMobile: widget.isMobile,
              ),

            // Profile / Login button - FIRST for mobile accessibility
            // Bigger tap target on mobile
            if (isAuthenticated)
              Container(
                margin: EdgeInsets.only(bottom: widget.isMobile ? 8 : 6),
                child: _NavItem(
                  icon: Icons.person_outline,
                  label: 'My Profile',
                  isPanelVisible: widget.isPanelVisible,
                  isMobile: widget.isMobile,
                  onTap: () {
                    showProfileDialog(context);
                  },
                ),
              )
            else
              Container(
                margin: EdgeInsets.only(bottom: widget.isMobile ? 8 : 6),
                child: _NavItem(
                  icon: Icons.person_outline,
                  label: 'Login / Register',
                  isPanelVisible: widget.isPanelVisible,
                  isMobile: widget.isMobile,
                  variant: _NavItemVariant.filled,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const LoginRegisterDialog(),
                    );
                  },
                ),
              ),

            // Settings button
            Container(
              margin: EdgeInsets.only(bottom: widget.isMobile ? 8 : 6),
              child: _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isPanelVisible: widget.isPanelVisible,
                isMobile: widget.isMobile,
                onTap: () {
                  showSettingsDialog(context);
                },
              ),
            ),

            // Feedback button
            _NavItem(
              icon: Icons.mail_outline,
              label: 'Send Feedback',
              isPanelVisible: widget.isPanelVisible,
              isMobile: widget.isMobile,
              onTap: () {
                // TODO: Open feedback dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Feedback dialog - TODO')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Navigation item widget
enum _NavItemVariant { ghost, filled, outline }

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: isPanelVisible ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          isPanelVisible ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: isMobile ? 22 : 20,
          color: isActive ? Theme.of(context).primaryColor : null,
        ),
        if (isPanelVisible) ...[
          SizedBox(width: isMobile ? 14 : 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 15 : 14,
                color: isActive ? Theme.of(context).primaryColor : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final button = InkWell(
      onTap: onTap ?? (route != null ? () => context.go(route!) : null),
      borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
      child: Container(
        padding: isPanelVisible
            ? EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 12,
                vertical: isMobile ? 14 : 10,
              )
            : EdgeInsets.all(isMobile ? 10 : 8),
        decoration: BoxDecoration(
          color: variant == _NavItemVariant.filled
              ? Theme.of(context).primaryColor
              : isActive
                  ? Theme.of(context).primaryColor.withAlpha(25)
                  : null,
          borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
        ),
        child: variant == _NavItemVariant.filled
            ? DefaultTextStyle(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: isMobile ? 15 : 14,
                ),
                child: IconTheme(
                  data: IconThemeData(
                      color: Theme.of(context).colorScheme.onPrimary),
                  child: content,
                ),
              )
            : content,
      ),
    );

    if (!isPanelVisible) {
      return Tooltip(
        message: label,
        child: button,
      );
    }


    return button;
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
    if (value == -1) return true;
    if (value is num && value < 0) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final stats = subscriptionProvider.stats;
    final theme = Theme.of(context);

    // Show nothing if no stats and not loading
    if (stats == null && !subscriptionProvider.isLoading && subscriptionProvider.error == null) {
      return const SizedBox.shrink();
    }
    // Show loading state
    if (subscriptionProvider.isLoading && stats == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(76),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withAlpha(128)),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Show error state
    if (subscriptionProvider.error != null && stats == null) {
      return const SizedBox.shrink(); // Silently hide on error
    }

    if (stats == null) {
      return const SizedBox.shrink();
    }

    final role = stats.role.toUpperCase();
    final isPro = role == 'PRO' || role == 'EXPERT';

    // Calculate usage percentages
    final questionsUsed = stats.usage['questions_period'] as int? ?? 0;
    final questionsLimit = stats.limits['max_questions_period'];
    final questionsLimitVal = questionsLimit is num ? questionsLimit.toInt() : 0;
    final questionsInfinite = _isUnlimited(questionsLimit);

    final filesUsed = stats.usage['files'] as int? ?? 0;
    final filesLimit = stats.limits['max_files'];
    final filesLimitVal = filesLimit is num ? filesLimit.toInt() : 0;
    final filesInfinite = _isUnlimited(filesLimit);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(76),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPro ? theme.primaryColor : theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
              if (!isPro)
                InkWell(
                  onTap: () {
                    showProfileDialog(context);
                    // Note: Tab controller is inside the dialog, so we can't directly switch tabs
                    // User will need to navigate to the Subscription tab manually
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'UPGRADE',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!questionsInfinite) ...[
            _buildProgressBar(context, 'Questions', questionsUsed, questionsLimitVal),
            const SizedBox(height: 4),
          ],
          if (!filesInfinite)
            _buildProgressBar(context, 'Files', filesUsed, filesLimitVal),
          if (questionsInfinite && filesInfinite)
            Text(
              'Unlimited resources',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, String label, int used, int limit) {
    final theme = Theme.of(context);
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            Text('$used/$limit', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: progress > 0.9 ? theme.colorScheme.error : theme.primaryColor,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}
