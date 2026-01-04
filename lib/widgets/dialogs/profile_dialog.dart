import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/models.dart';
import '../../models/subscription_stats.dart';
import '../../services/auth_service.dart';
import '../profile/memories_section.dart';
import '../profile/subscription_section.dart';

/// Shows the profile dialog as a full-screen modal
void showProfileDialog(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 768;

  if (isMobile) {
    // Full screen modal for mobile
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ProfileScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  } else {
    // Regular dialog for desktop
    showDialog(
      context: context,
      builder: (context) => const ProfileDialog(),
    );
  }
}

/// Full-screen profile for mobile with swipe-to-close
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Fetch subscription stats when profile is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity > 500 || _dragOffset > 150) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Scaffold(
          backgroundColor: cs.surface,
          body: SafeArea(
            child: Column(
              children: [
                // Drag handle indicator
                _buildDragHandle(cs),

                // Header with close button
                _buildHeader(context, cs),

                // Tab bar
                _buildTabBar(cs),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ProfileContent(
                        user: user,
                        subscriptionStats: subscriptionProvider.stats,
                        onUpgradeTap: () => _showSubscriptionSheet(context),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: MemoriesSection(),
                      ),
                      const _PasswordContent(),
                      _AccountContent(user: user),
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

  void _showSubscriptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Subscription Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Plans
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const SubscriptionSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(ColorScheme cs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your account settings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: cs.onPrimaryContainer,
        unselectedLabelColor: cs.onSurfaceVariant,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: const [
          Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Profile'),
          Tab(icon: Icon(Icons.psychology_outlined, size: 20), text: 'Memory'),
          Tab(icon: Icon(Icons.lock_outline, size: 20), text: 'Password'),
          Tab(icon: Icon(Icons.settings_outlined, size: 20), text: 'Account'),
        ],
      ),
    );
  }
}

/// Desktop dialog version
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Fetch subscription stats when profile is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Subscription Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Expanded(child: SubscriptionSection()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = authProvider.currentUser;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Profile', icon: Icon(Icons.person_outline)),
                Tab(text: 'Memories', icon: Icon(Icons.psychology_outlined)),
                Tab(text: 'Password', icon: Icon(Icons.lock_outline)),
                Tab(text: 'Account', icon: Icon(Icons.manage_accounts_outlined)),
              ],
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ProfileContent(
                    user: user,
                    subscriptionStats: subscriptionProvider.stats,
                    onUpgradeTap: () => _showSubscriptionDialog(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: MemoriesSection(),
                  ),
                  const _PasswordContent(),
                  _AccountContent(user: user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final User? user;
  final SubscriptionStats? subscriptionStats;
  final VoidCallback? onUpgradeTap;

  const _ProfileContent({
    required this.user,
    this.subscriptionStats,
    this.onUpgradeTap,
  });

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  bool _isEditingUsername = false;
  bool _isSaving = false;
  final _usernameController = TextEditingController();
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user?.name ?? '';
  }

  @override
  void didUpdateWidget(covariant _ProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.name != widget.user?.name && !_isEditingUsername) {
      _usernameController.text = widget.user?.name ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String _getDisplayRole() {
    // Priority: subscriptionStats role > user role > default
    final statsRole = widget.subscriptionStats?.displayRole;
    final userRole = widget.user?.role;

    if (statsRole != null && statsRole.isNotEmpty && statsRole != 'Free') {
      return statsRole;
    }

    if (userRole != null && userRole.isNotEmpty) {
      switch (userRole.toLowerCase()) {
        case 'expert':
          return 'Expert';
        case 'pro':
          return 'Pro';
        default:
          return 'Free';
      }
    }

    return 'Free';
  }

  bool _isPremiumRole() {
    final role = _getDisplayRole().toLowerCase();
    return role == 'pro' || role == 'expert';
  }

  String? _getFormattedExpiry() {
    // Use subscriptionStats expiry as priority
    if (widget.subscriptionStats?.formattedExpiry != null) {
      return widget.subscriptionStats!.formattedExpiry;
    }

    // Try to format user's roleExpiry if available
    final expiry = widget.user?.roleExpiry;
    if (expiry == null) return null;

    try {
      final date = DateTime.parse(expiry);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return expiry;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = _getDisplayRole();
    final isPremium = _isPremiumRole();
    final roleExpiry = _getFormattedExpiry();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.primaryContainer.withAlpha(150)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primary.withAlpha(30),
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user?.name ?? widget.user?.email ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                if (widget.user?.email != null)
                  Text(
                    widget.user!.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer.withAlpha(180),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Subscription Card
          _buildSubscriptionCard(context, role, isPremium, roleExpiry, cs),

          const SizedBox(height: 16),

          // Editable Nickname card
          _buildEditableNicknameCard(context, cs),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.workspace_premium_outlined,
            label: 'Role',
            value: role,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.email_outlined,
            label: 'E-mail',
            value: widget.user?.email ?? 'Not available',
          ),

          const SizedBox(height: 12),

          // Role Expiry - only show for premium users
          if (isPremium && roleExpiry != null) ...[
            _buildInfoCard(
              context,
              icon: Icons.event_outlined,
              label: 'Role Expiry',
              value: roleExpiry,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 32),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSubscriptionCard(
    BuildContext context,
    String role,
    bool isPremium,
    String? roleExpiry,
    ColorScheme cs,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
          ? LinearGradient(
              colors: [
                Colors.amber.shade700.withAlpha(40),
                Colors.orange.shade600.withAlpha(30),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
        color: isPremium ? null : cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium ? Colors.amber.shade600.withAlpha(80) : cs.outlineVariant.withAlpha(50),
          width: isPremium ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon, role and badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPremium
                    ? Colors.amber.shade600.withAlpha(30)
                    : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.person_outline,
                  color: isPremium ? Colors.amber.shade600 : cs.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          role,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPremium ? Colors.amber.shade700 : cs.onSurface,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Active',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Expiry info for premium users
          if (isPremium && roleExpiry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface.withAlpha(150),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Valid until: $roleExpiry',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Upgrade button for non-premium users
          if (!isPremium && onUpgradeTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onUpgradeTap,
                icon: const Icon(Icons.upgrade, size: 20),
                label: const Text('Upgrade Plan'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          // Manage subscription for premium users
          if (isPremium && onUpgradeTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onUpgradeTap,
                icon: const Icon(Icons.settings_outlined, size: 20),
                label: const Text('Manage Subscription'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.amber.shade600.withAlpha(100)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableNicknameCard(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditingUsername
              ? cs.primary.withAlpha(100)
              : cs.outlineVariant.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.badge_outlined, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isEditingUsername
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nickname',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: _usernameError,
                          hintText: 'Enter nickname',
                        ),
                        autofocus: true,
                        onSubmitted: (_) => _saveUsername(),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nickname',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user?.name ?? 'Not set',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_isEditingUsername) ...[
            if (_isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(
                icon: Icon(Icons.check, color: cs.primary),
                onPressed: _saveUsername,
                tooltip: 'Save',
              ),
              IconButton(
                icon: Icon(Icons.close, color: cs.error),
                onPressed: () {
                  setState(() {
                    _isEditingUsername = false;
                    _usernameController.text = widget.user?.name ?? '';
                    _usernameError = null;
                  });
                },
                tooltip: 'Cancel',
              ),
            ],
          ] else
            IconButton(
              icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
              onPressed: () {
                setState(() {
                  _isEditingUsername = true;
                });
              },
              tooltip: 'Edit nickname',
            ),
        ],
      ),
    );
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();

    if (newUsername.isEmpty) {
      setState(() {
        _usernameError = 'Nickname cannot be empty';
      });
      return;
    }

    if (newUsername.length < 3) {
      setState(() {
        _usernameError = 'Nickname must be at least 3 characters';
      });
      return;
    }

    if (newUsername.length > 50) {
      setState(() {
        _usernameError = 'Nickname must be less than 50 characters';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _usernameError = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final (success, error) = await authProvider.updateUsername(newUsername);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          setState(() {
            _isEditingUsername = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nickname updated successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _usernameError = error ?? 'Failed to update nickname';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _usernameError = 'An error occurred';
        });
      }
    }
  }

  VoidCallback? get onUpgradeTap => widget.onUpgradeTap;

  Widget _buildInfoCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

/// Password change content
class _PasswordContent extends StatefulWidget {
  const _PasswordContent();

  @override
  State<_PasswordContent> createState() => _PasswordContentState();
}

class _PasswordContentState extends State<_PasswordContent> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Change your password regularly to keep your account secure.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildPasswordField(
              controller: _currentPasswordController,
              label: 'Current Password',
              obscure: _obscureCurrentPassword,
              onToggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
            ),

            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              obscure: _obscureNewPassword,
              onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),

            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleChangePassword,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  Future<void> _handleChangePassword() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final (success, error) = await authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        // Clear form
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to change password'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Account management content
class _AccountContent extends StatelessWidget {
  final User? user;

  const _AccountContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Danger zone
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.errorContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.error.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Deleting your account is permanent. All your data including flashcards, exams, and study progress will be permanently removed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDeleteAccount(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you absolutely sure? This action cannot be undone. '
          'All your data will be permanently deleted.',
        ),
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

    if (confirmed == true && context.mounted) {
      // TODO: Implement account deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion not yet implemented')),
      );
    }
  }
}


