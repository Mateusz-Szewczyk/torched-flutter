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

// --- Reusable Glass Components ---

/// A container that applies a blur, semi-transparent background, and subtle border
class GlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const GlassTile({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 15,
    this.opacity = 0.05,
    this.color,
    this.border,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? cs.surface.withOpacity(opacity),
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              border: border ?? Border.all(
                color: cs.onSurface.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A text field with no solid fill, just a glowing outline when focused
class GhostTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final String? errorText;

  const GhostTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.validator,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      autofocus: autofocus,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cs.surface.withOpacity(0.02),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error.withOpacity(0.5)),
        ),
      ),
    );
  }
}

// --- Main Implementation ---

/// Shows the profile dialog as a full-screen modal
void showProfileDialog(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 768;

  if (isMobile) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Crucial for glassmorphism
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.6),
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
              curve: Curves.easeOutQuart,
            )),
            child: child,
          );
        },
      ),
    );
  } else {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
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
          backgroundColor: Colors.transparent, // Transparent for Glass effect
          body: Stack(
            children: [
              // 1. The Blur Layer
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: cs.surface.withOpacity(0.75),
                  ),
                ),
              ),

              // 2. The Content
              SafeArea(
                child: Column(
                  children: [
                    // Glowing Drag handle
                    _buildDragHandle(cs),

                    // Header
                    _buildHeader(context, cs),

                    // Segmented Glass Tabs
                    _buildTabBar(cs),

                    // Tab View
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
            ],
          ),
        ),
      ),
    );
  }

  void _showSubscriptionSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            color: cs.surface.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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

  Widget _buildDragHandle(ColorScheme cs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Profile',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Settings & Preferences',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest.withOpacity(0.3),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: cs.primaryContainer.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: cs.onPrimaryContainer,
        unselectedLabelColor: cs.onSurfaceVariant,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Memory'),
          Tab(text: 'Security'),
          Tab(text: 'Account'),
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
        backgroundColor: Colors.transparent,
        child: GlassTile(
          opacity: 0.9,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Text(
                        'Subscription Plans',
                        style: Theme.of(context).textTheme.headlineSmall,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = authProvider.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: GlassTile(
          opacity: 0.85,
          blur: 25,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                          'My Profile',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                         ),
                         Text(
                           'Manage your digital identity',
                           style: Theme.of(context).textTheme.bodySmall?.copyWith(
                             color: cs.onSurfaceVariant
                           ),
                         )
                       ],
                     ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Glass Capsule Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: cs.primaryContainer.withOpacity(0.3), blurRadius: 8),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: cs.onPrimaryContainer,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
                    Tab(icon: Icon(Icons.psychology_outlined), text: 'Memories'),
                    Tab(icon: Icon(Icons.lock_outline), text: 'Security'),
                    Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Account'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                      padding: EdgeInsets.all(24.0),
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
                        color: cs.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
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

          // Neon Logout Button
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
      // Premium gets golden gradient border, Free gets standard
      border: isPremium
        ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5)
        : null,
      shadows: isPremium
        ? [BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 25, spreadRadius: -5)]
        : null,
      gradient: isPremium
        ? LinearGradient(
            colors: [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null,
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
                    color: cs.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
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
              color: cs.primary.withOpacity(0.05),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
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
              prefixIcon: const Icon(Icons.lock_outline),
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
              prefixIcon: const Icon(Icons.key_outlined),
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
              prefixIcon: const Icon(Icons.check_circle_outline),
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
                    color: cs.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
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
          GlassTile(
            padding: const EdgeInsets.all(24),
            color: cs.error.withOpacity(0.05),
            border: Border.all(color: cs.error.withOpacity(0.3)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: cs.error),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting your account is permanent. All your data including flashcards, exams, and study progress will be permanently removed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDeleteAccount(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withOpacity(0.5)),
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
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassTile(
          opacity: 0.95,
          padding: const EdgeInsets.all(24),
          border: Border.all(color: cs.error.withOpacity(0.3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, size: 48, color: cs.error),
              const SizedBox(height: 16),
              const Text('Delete Account?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Are you absolutely sure? This action cannot be undone. All your data will be permanently deleted.',
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

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion not yet implemented')),
      );
    }
  }
}