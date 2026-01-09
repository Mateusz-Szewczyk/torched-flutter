import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/models.dart';
import '../../models/subscription_stats.dart';
import '../../services/auth_service.dart';
import '../profile/memories_section.dart';
import '../profile/subscription_section.dart';
import '../common/glass_components.dart';
import 'base_glass_dialog.dart';

// --- Main Implementation ---

/// Shows the profile dialog
void showProfileDialog(BuildContext context) {
  BaseGlassDialog.show(
    context,
    builder: (context) => const ProfileDialog(),
  );
}

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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSubscriptionSheet(BuildContext context) {
    // ... reusing the mobile sheet logic for simplicity across platforms or keep separate?
    // The previous implementation had distinct logic.
    // We'll use a modal bottom sheet for both
    final cs = Theme.of(context).colorScheme;

    // Using BaseGlassDialog for subscription sheet as well?
    // It might stack weirdly if we abuse it. Let's use showModalBottomSheet with a custom glass container.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
               decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.9),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          'Subscription Plans',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = authProvider.currentUser;
    final cs = Theme.of(context).colorScheme;

    return BaseGlassDialog(
      maxWidth: 700,
      maxHeight: 750,
      header: _buildHeaderWithTabs(context, cs),
      child: TabBarView(
          controller: _tabController,
          children: [
            _ProfileContent(
              user: user,
              subscriptionStats: subscriptionProvider.stats,
              onUpgradeTap: () => _showSubscriptionSheet(context),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: MemoriesSection(),
            ),
            _CombinedAccountContent(user: user),
          ],
        ),
    );
  }

  Widget _buildHeaderWithTabs(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Tabs in header
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: cs.onPrimaryContainer,
                unselectedLabelColor: cs.onSurfaceVariant,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(height: 40, icon: Icon(Icons.person_outline, size: 20), text: 'Profile'),
                  Tab(height: 40, icon: Icon(Icons.psychology_outlined, size: 20), text: 'Memories'),
                  Tab(height: 40, icon: Icon(Icons.manage_accounts_outlined, size: 20), text: 'Account'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest.withAlpha(80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
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
    final statsRole = widget.subscriptionStats?.displayRole;
    final userRole = widget.user?.role;

    if (statsRole != null && statsRole.isNotEmpty && statsRole != 'Free') {
      return statsRole;
    }

    if (userRole != null && userRole.isNotEmpty) {
      switch (userRole.toLowerCase()) {
        case 'expert': return 'Expert';
        case 'pro': return 'Pro';
        default: return 'Free';
      }
    }
    return 'Free';
  }

  bool _isPremiumRole() {
    final role = _getDisplayRole().toLowerCase();
    return role == 'pro' || role == 'expert';
  }

  String? _getFormattedExpiry() {
    if (widget.subscriptionStats?.formattedExpiry != null) {
      return widget.subscriptionStats!.formattedExpiry;
    }
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
          // HUD Avatar & Identity
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(
                      widget.user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user?.name ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Subscription Card (Glass)
          _buildSubscriptionCard(context, role, isPremium, roleExpiry, cs),

          const SizedBox(height: 20),

          // Edit Nickname Glass Tile
          _buildEditableNicknameCard(context, cs),

          const SizedBox(height: 16),

          // Info Tiles
          Row(
            children: [
              Expanded(
                child: _buildInfoGlassTile(
                  context,
                  icon: Icons.workspace_premium_outlined,
                  label: 'Current Role',
                  value: role,
                  color: isPremium ? Colors.amber : cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoGlassTile(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Joined',
                  value: '2024', // Placeholder or add to model
                  color: cs.secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                foregroundColor: cs.onSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outline.withOpacity(0.2)),
                ),
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
    return GlassTile(
      padding: const EdgeInsets.all(20),
      color: isPremium ? Colors.amber : null,
      opacity: isPremium ? 0.1 : 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPremium ? Colors.amber.withOpacity(0.2) : cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: isPremium ? Border.all(color: Colors.amber.withOpacity(0.3)) : null,
                ),
                child: Icon(
                  isPremium ? Icons.auto_awesome : Icons.person_outline,
                  color: isPremium ? Colors.amber : cs.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Status',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isPremium ? Colors.amber : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),

          if (isPremium && roleExpiry != null) ...[
            const SizedBox(height: 16),
            Text(
              'Valid until $roleExpiry',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],

          if (!isPremium && onUpgradeTap != null) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: onUpgradeTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('UPGRADE TO PRO'),
              ),
            ),
          ],

          if (isPremium && onUpgradeTap != null) ...[
             const SizedBox(height: 20),
             OutlinedButton(
               onPressed: onUpgradeTap,
               style: OutlinedButton.styleFrom(
                 minimumSize: const Size(double.infinity, 48),
                 foregroundColor: cs.onSurface,
                 side: BorderSide(color: cs.outline.withOpacity(0.3)),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
               child: const Text('Manage Subscription'),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableNicknameCard(BuildContext context, ColorScheme cs) {
    return GlassTile(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.badge_outlined, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isEditingUsername
                ? GhostTextField(
                    controller: _usernameController,
                    label: 'Nickname',
                    autofocus: true,
                    errorText: _usernameError,
                    onSubmitted: (_) => _saveUsername(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Name',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user?.name ?? 'Not set',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_isEditingUsername) ...[
            if (_isSaving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                ),
              )
            else ...[
              IconButton(
                icon: Icon(Icons.check_circle, color: cs.primary),
                onPressed: _saveUsername,
              ),
              IconButton(
                icon: Icon(Icons.cancel, color: cs.error),
                onPressed: () {
                  setState(() {
                    _isEditingUsername = false;
                    _usernameController.text = widget.user?.name ?? '';
                    _usernameError = null;
                  });
                },
              ),
            ]
          ] else
            IconButton(
              icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant.withOpacity(0.7)),
              onPressed: () {
                setState(() {
                  _isEditingUsername = true;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoGlassTile(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = color ?? cs.primary;

    return GlassTile(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();

    if (newUsername.isEmpty) {
      setState(() => _usernameError = 'Nickname cannot be empty');
      return;
    }

    if (newUsername.length < 3) {
      setState(() => _usernameError = 'Min 3 characters');
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
        setState(() => _isSaving = false);

        if (success) {
          setState(() => _isEditingUsername = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Identity updated'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          setState(() => _usernameError = error ?? 'Failed to update');
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

  Future<void> _handleLogout(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassTile(
          opacity: 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout, size: 48, color: cs.primary),
              const SizedBox(height: 16),
              const Text('Disconnect?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Are you sure you want to log out?', textAlign: TextAlign.center),
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
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            GlassTile(
              padding: const EdgeInsets.all(16),
              color: cs.primary,
              opacity: 0.05,
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keep your account secure with a strong password.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GhostTextField(
              controller: _currentPasswordController,
              label: 'Current Password',
              obscureText: _obscureCurrentPassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrentPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            GhostTextField(
              controller: _newPasswordController,
              label: 'New Password',
              obscureText: _obscureNewPassword,
              prefixIcon: Icons.key_outlined,
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            GhostTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icons.check_circle_outline,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) {
                if (value != _newPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              ),
              child: FilledButton(
                onPressed: _isLoading ? null : _handleChangePassword,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                      )
                    : const Text('Update Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
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
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
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

/// Combined Account content - includes password change and danger zone
class _CombinedAccountContent extends StatefulWidget {
  final User? user;

  const _CombinedAccountContent({required this.user});

  @override
  State<_CombinedAccountContent> createState() => _CombinedAccountContentState();
}

class _CombinedAccountContentState extends State<_CombinedAccountContent> {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Password Change Section
          Text(
            'Change Password',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your account secure with a strong password',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                GhostTextField(
                  controller: _currentPasswordController,
                  labelText: 'Current Password',
                  obscureText: _obscureCurrentPassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                GhostTextField(
                  controller: _newPasswordController,
                  labelText: 'New Password',
                  obscureText: _obscureNewPassword,
                  prefixIcon: Icons.key_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                GhostTextField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm New Password',
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icons.check_circle_outline,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value != _newPasswordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _handleChangePassword,
              icon: _isLoading
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : const Icon(Icons.lock_reset, size: 18),
              label: const Text('Update Password'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Danger Zone Divider
          Row(
            children: [
              Expanded(child: Divider(color: cs.error.withAlpha(80))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'DANGER ZONE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Divider(color: cs.error.withAlpha(80))),
            ],
          ),

          const SizedBox(height: 20),

          // Delete Account Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.errorContainer.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Delete Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This action is permanent. All your data including flashcards, exams, and study progress will be deleted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withAlpha(180),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDeleteAccount(context),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Delete My Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withAlpha(120)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Password updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: cs.error),
            const SizedBox(width: 12),
            const Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you absolutely sure? This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion not yet implemented')),
      );
    }
  }
}
