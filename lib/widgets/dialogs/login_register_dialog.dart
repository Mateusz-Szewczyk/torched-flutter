import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';
import 'base_glass_dialog.dart';

/// Login/Register Dialog - Glassmorphism & Futuristic Minimalist Design
/// Supports email/password auth and OAuth (Google, GitHub)
class LoginRegisterDialog extends StatefulWidget {
  final String initialView; // 'auth', 'forgot-password', 'reset-password'
  final String? resetToken;

  const LoginRegisterDialog({
    super.key,
    this.initialView = 'auth',
    this.resetToken,
  });

  static Future<dynamic> show(BuildContext context, {String initialView = 'auth'}) {
    return BaseGlassDialog.show(
      context,
      builder: (context) => LoginRegisterDialog(initialView: initialView),
    );
  }

  @override
  State<LoginRegisterDialog> createState() => _LoginRegisterDialogState();
}

class _LoginRegisterDialogState extends State<LoginRegisterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentView;

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _forgotFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register controllers
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Forgot password controller
  final _forgotEmailController = TextEditingController();

  // Reset password controllers
  final _resetPasswordController = TextEditingController();
  final _resetConfirmController = TextEditingController();
  String _resetToken = '';

  // Password visibility
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureResetPassword = true;
  bool _obscureResetConfirm = true;

  // Loading states
  bool _isLoading = false;

  // Tab state for custom tab indicator
  int _selectedTabIndex = 0;

  // Password validation state
  final Map<String, bool> _passwordRequirements = {
    'length': false,
    'lowercase': false,
    'uppercase': false,
    'number': false,
    'special': false,
  };

  // Toast message
  String? _toastMessage;
  String _toastType = 'info'; // 'success', 'error', 'info'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _currentView = widget.initialView;
    _resetToken = widget.resetToken ?? '';

    _registerPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _forgotEmailController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _registerPasswordController.text;
    setState(() {
      _passwordRequirements['length'] = password.length >= 8;
      _passwordRequirements['lowercase'] = password.contains(RegExp(r'[a-z]'));
      _passwordRequirements['uppercase'] = password.contains(RegExp(r'[A-Z]'));
      _passwordRequirements['number'] = password.contains(RegExp(r'[0-9]'));
      _passwordRequirements['special'] =
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid =>
      _passwordRequirements.values.every((met) => met);

  void _showToast(String message, String type) {
    setState(() {
      _toastMessage = message;
      _toastType = type;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  // ============================================================================
  // LOGIN
  // ============================================================================

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _loginEmailController.text.trim(),
      _loginPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _showToast('Zalogowano pomyślnie!', 'success');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop(true);
        // Refresh session to load user data
        await authProvider.checkSession();
      }
    } else if (mounted) {
      _showToast(
        authProvider.errorMessage ?? 'Nie udało się zalogować',
        'error',
      );
    }
  }

  // ============================================================================
  // REGISTER
  // ============================================================================

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    if (!_isPasswordValid) {
      _showToast('Hasło nie spełnia wszystkich wymagań', 'error');
      return;
    }

    if (_registerPasswordController.text != _confirmPasswordController.text) {
      _showToast('Hasła nie są identyczne', 'error');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _registerEmailController.text.trim(),
      _registerPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _showToast(
        'Zarejestrowano pomyślnie! Sprawdź email aby potwierdzić konto.',
        'success',
      );
      // Switch to login tab
      _tabController.animateTo(0);
      _registerEmailController.clear();
      _registerPasswordController.clear();
      _confirmPasswordController.clear();
    } else if (mounted) {
      _showToast(
        authProvider.errorMessage ?? 'Nie udało się zarejestrować',
        'error',
      );
    }
  }

  // ============================================================================
  // OAUTH
  // ============================================================================

  Future<void> _handleOAuthLogin(String provider) async {
    final url = '${AppConfig.apiBaseUrl}${AppConfig.authEndpoint}/$provider';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showToast('Nie można otworzyć strony logowania', 'error');
      }
    } catch (e) {
      _showToast('Błąd podczas logowania OAuth: $e', 'error');
    }
  }

  // ============================================================================
  // FORGOT PASSWORD
  // ============================================================================

  Future<void> _handleForgotPassword() async {
    if (!_forgotFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.requestPasswordReset(
      _forgotEmailController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _showToast(
        'Jeśli podany email istnieje, wysłaliśmy link do resetowania hasła.',
        'success',
      );
      setState(() => _currentView = 'auth');
    } else if (mounted) {
      _showToast('Wystąpił błąd. Spróbuj ponownie później.', 'error');
    }
  }

  // ============================================================================
  // RESET PASSWORD
  // ============================================================================

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    if (_resetPasswordController.text != _resetConfirmController.text) {
      _showToast('Hasła nie są identyczne', 'error');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      _resetToken,
      _resetPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _showToast(
        'Hasło zostało zmienione. Możesz się teraz zalogować.',
        'success',
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _currentView = 'auth');
      }
    } else if (mounted) {
      _showToast('Nie udało się zmienić hasła. Link mógł wygasnąć.', 'error');
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseGlassDialog(
      maxWidth: 450,
      maxHeight: 680,
      header: _buildHeader(colorScheme, isDark),
      // BaseGlassDialog includes close button support via header checks?
      // I'll pass a custom header which INCLUDES the close button and title logic of existing dialog
      child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toast
                if (_toastMessage != null) _buildToast(colorScheme, isDark),

                // Content based on view
                Flexible(
                  child: _currentView == 'auth'
                      ? _buildAuthView(colorScheme, isDark)
                      : _currentView == 'forgot-password'
                          ? _buildForgotPasswordView(colorScheme, isDark)
                          : _buildResetPasswordView(colorScheme, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isDark) {
    String title;
    String subtitle;
    IconData icon;

    switch (_currentView) {
      case 'forgot-password':
        title = 'Reset Password';
        subtitle = 'Recover your account';
        icon = Icons.lock_reset_rounded;
        break;
      case 'reset-password':
        title = 'New Password';
        subtitle = 'Create a new password';
        icon = Icons.password_rounded;
        break;
      default:
        title = 'Welcome';
        subtitle = 'Sign in to continue';
        icon = Icons.auto_awesome_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          // Back button
          if (_currentView != 'auth') ...[
            _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => setState(() => _currentView = 'auth'),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
          ],

          // Title area
          Expanded(
            child: Row(
              children: [
                // Icon with glow
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.2),
                        colorScheme.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close button
          _GlassIconButton(
            icon: Icons.close_rounded,
            onPressed: () => Navigator.pop(context),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToast(ColorScheme colorScheme, bool isDark) {
    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (_toastType) {
      case 'success':
        bgColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green.withOpacity(0.3);
        icon = Icons.check_circle_rounded;
        break;
      case 'error':
        bgColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red.withOpacity(0.3);
        icon = Icons.error_rounded;
        break;
      default:
        bgColor = colorScheme.primary.withOpacity(0.15);
        borderColor = colorScheme.primary.withOpacity(0.3);
        icon = Icons.info_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: _toastType == 'success'
                      ? Colors.green
                      : _toastType == 'error'
                          ? Colors.red
                          : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _toastMessage!,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _toastMessage = null),
                  child: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // AUTH VIEW (Login/Register)
  // ============================================================================

  Widget _buildAuthView(ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        // Custom Segmented Tab Switcher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildSegmentedTabs(colorScheme, isDark),
        ),
        const SizedBox(height: 20),

        // Tab content
        Flexible(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLoginTab(colorScheme, isDark),
              _buildRegisterTab(colorScheme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabs(ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildSegmentTab(
            label: 'Sign In',
            isSelected: _selectedTabIndex == 0,
            onTap: () => _tabController.animateTo(0),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
          _buildSegmentTab(
            label: 'Sign Up',
            isSelected: _selectedTabIndex == 1,
            onTap: () => _tabController.animateTo(1),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(ColorScheme colorScheme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // OAuth buttons
          _buildOAuthButtons(colorScheme, isDark),

          const SizedBox(height: 20),
          _buildDivider(colorScheme, isDark),
          const SizedBox(height: 20),

          // Login form
          Form(
            key: _loginFormKey,
            child: Column(
              children: [
                _GlassTextField(
                  controller: _loginEmailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _GlassTextField(
                  controller: _loginPasswordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureLoginPassword,
                  suffixIcon: _obscureLoginPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () => setState(
                      () => _obscureLoginPassword = !_obscureLoginPassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _buildPrimaryButton(
                  label: 'Sign In',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => _currentView = 'forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13, letterSpacing: 0.2),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(ColorScheme colorScheme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // OAuth buttons
          _buildOAuthButtons(colorScheme, isDark),

          const SizedBox(height: 20),
          _buildDivider(colorScheme, isDark),
          const SizedBox(height: 20),

          // Register form
          Form(
            key: _registerFormKey,
            child: Column(
              children: [
                _GlassTextField(
                  controller: _registerEmailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _GlassTextField(
                  controller: _registerPasswordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureRegisterPassword,
                  suffixIcon: _obscureRegisterPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () => setState(() =>
                      _obscureRegisterPassword = !_obscureRegisterPassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),

                // Password strength indicator
                _buildPasswordStrength(colorScheme, isDark),

                const SizedBox(height: 14),
                _GlassTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () => setState(() =>
                      _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _registerPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _buildPrimaryButton(
                  label: 'Create Account',
                  onPressed: _handleRegister,
                  isLoading: _isLoading,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthButtons(ColorScheme colorScheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _OAuthButton(
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            onPressed: () => _handleOAuthLogin('google'),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OAuthButton(
            icon: Icons.code_rounded,
            label: 'GitHub',
            onPressed: () => _handleOAuthLogin('github'),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme colorScheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  colorScheme.outlineVariant.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outlineVariant.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength(ColorScheme colorScheme, bool isDark) {
    if (_registerPasswordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final metCount = _passwordRequirements.values.where((v) => v).length;
    final progress = metCount / 5;

    Color strengthColor;
    String strengthLabel;

    if (progress <= 0.4) {
      strengthColor = Colors.red;
      strengthLabel = 'Weak';
    } else if (progress <= 0.7) {
      strengthColor = Colors.orange;
      strengthLabel = 'Medium';
    } else {
      strengthColor = Colors.green;
      strengthLabel = 'Strong';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password Strength',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 4,
                  width: MediaQuery.of(context).size.width * progress * 0.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        strengthColor.withOpacity(0.7),
                        strengthColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: strengthColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Requirements pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _RequirementPill(
                label: '8+ chars',
                met: _passwordRequirements['length']!,
                colorScheme: colorScheme,
              ),
              _RequirementPill(
                label: 'a-z',
                met: _passwordRequirements['lowercase']!,
                colorScheme: colorScheme,
              ),
              _RequirementPill(
                label: 'A-Z',
                met: _passwordRequirements['uppercase']!,
                colorScheme: colorScheme,
              ),
              _RequirementPill(
                label: '0-9',
                met: _passwordRequirements['number']!,
                colorScheme: colorScheme,
              ),
              _RequirementPill(
                label: '!@#\$',
                met: _passwordRequirements['special']!,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  // ============================================================================
  // FORGOT PASSWORD VIEW
  // ============================================================================

  Widget _buildForgotPasswordView(ColorScheme colorScheme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _forgotFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon with glow
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Enter your email address and we\'ll send you a password reset link.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _GlassTextField(
              controller: _forgotEmailController,
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Send Reset Link',
              onPressed: _handleForgotPassword,
              isLoading: _isLoading,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // RESET PASSWORD VIEW
  // ============================================================================

  Widget _buildResetPasswordView(ColorScheme colorScheme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon with glow
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.password_rounded,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create a new password for your account.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _GlassTextField(
              controller: _resetPasswordController,
              label: 'New Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureResetPassword,
              suffixIcon: _obscureResetPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffixTap: () => setState(
                  () => _obscureResetPassword = !_obscureResetPassword),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 8) {
                  return 'Minimum 8 characters';
                }
                return null;
              },
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _GlassTextField(
              controller: _resetConfirmController,
              label: 'Confirm New Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureResetConfirm,
              suffixIcon: _obscureResetConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffixTap: () => setState(
                  () => _obscureResetConfirm = !_obscureResetConfirm),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm password';
                }
                if (value != _resetPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Change Password',
              onPressed: _handleResetPassword,
              isLoading: _isLoading,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // VALIDATORS
  // ============================================================================

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email address';
    }
    return null;
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

/// Glass-style Icon Button
class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isDark;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.06))
                : (widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Glass-style Text Field
class _GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ColorScheme colorScheme;
  final bool isDark;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused
              ? widget.colorScheme.primary.withOpacity(0.6)
              : (widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08)),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: widget.colorScheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: TextStyle(
            color: widget.colorScheme.onSurface,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused
                  ? widget.colorScheme.primary
                  : widget.colorScheme.onSurfaceVariant,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              size: 18,
              color: _isFocused
                  ? widget.colorScheme.primary
                  : widget.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            suffixIcon: widget.suffixIcon != null
                ? GestureDetector(
                    onTap: widget.onSuffixTap,
                    child: Icon(
                      widget.suffixIcon,
                      size: 18,
                      color: widget.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
          ),
        ),
      ),
    );
  }
}

/// OAuth Button with Glass Style
class _OAuthButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isDark;

  const _OAuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<_OAuthButton> createState() => _OAuthButtonState();
}

class _OAuthButtonState extends State<_OAuthButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05))
                : (widget.isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Password Requirement Pill
class _RequirementPill extends StatelessWidget {
  final String label;
  final bool met;
  final ColorScheme colorScheme;

  const _RequirementPill({
    required this.label,
    required this.met,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: met
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (met)
            Icon(
              Icons.check_rounded,
              size: 10,
              color: Colors.green,
            ),
          if (met) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: met ? Colors.green : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
