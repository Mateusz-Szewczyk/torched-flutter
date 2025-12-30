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
                          child: Image.asset(
                            'assets/images/favicon.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.broken_image,
                              size: 20,
                              color: Theme.of(context).primaryColor,
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
                        onPressed: () {
                          context.go('/');
                          // Auto-close panel on mobile after navigation
                          if (widget.isMobile) widget.togglePanel();
                        },
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
                  onPressed: () {
                    context.go('/');
                    if (widget.isMobile) widget.togglePanel();
                  },
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
              isMobile: widget.isMobile,
              onTap: () {
                // Navigate and close panel on mobile to avoid manual closing
                context.go('/flashcards');
                if (widget.isMobile) widget.togglePanel();
              },
            ),
            _NavItem(
              icon: Icons.quiz_outlined,
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
              icon: Icons.folder_outlined,
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
                    if (widget.isMobile) widget.togglePanel();
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
                    if (widget.isMobile) widget.togglePanel();
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
                  if (widget.isMobile) widget.togglePanel();
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
                if (widget.isMobile) widget.togglePanel();
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

    if (stats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final role = stats.role ?? 'user';
    final limits = stats.limits;
    final usage = stats.usage;

    double _calcProgress(num? used, num? limit) {
      if (used == null || limit == null) return 0.0;
      if (_isUnlimited(limit)) return 0.0;
      if (limit == 0) return 1.0;
      return (used / limit).clamp(0.0, 1.0).toDouble();
    }

    final filesProgress = _calcProgress(usage?['files'] as num?, limits?['max_files'] as num?);
    final decksProgress = _calcProgress(usage?['decks'] as num?, limits?['max_decks'] as num?);
    final questionsProgress = _calcProgress(usage?['questions_period'] as num?, limits?['max_questions_period'] as num?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (role == 'user'.toLowerCase()) ? 'free'.toUpperCase() : role.toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (role.toLowerCase() == 'user')
              TextButton(
                onPressed: () => _showSubscriptionView(context),
                child: const Text('Upgrade'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isPanelVisible) ...[
          _buildUsageRow(context, 'Files', usage?['files']?.toString() ?? '0', limits?['max_files']),
          const SizedBox(height: 6),
          _buildUsageRow(context, 'Decks', usage?['decks']?.toString() ?? '0', limits?['max_decks']),
          const SizedBox(height: 6),
          _buildUsageRow(context, 'Questions (period)', usage?['questions_period']?.toString() ?? '0', limits?['max_questions_period']),
        ],
      ],
    );
  }

  Widget _buildUsageRow(BuildContext context, String label, String usedText, dynamic limit) {
    final used = int.tryParse(usedText) ?? 0;
    final isUnlimited = _isUnlimited(limit);
    final limitText = isUnlimited ? '∞' : (limit?.toString() ?? '-');
    final progress = isUnlimited ? 0.0 : (limit is num ? (used / (limit as num)).clamp(0.0, 1.0).toDouble() : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            Text('$used/$limitText', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }
}
