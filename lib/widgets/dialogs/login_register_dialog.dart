import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';

/// Login/Register Dialog - equivalent to LoginRegisterDialog.tsx
/// Supports email/password auth and OAuth (Google, GitHub)
class LoginRegisterDialog extends StatefulWidget {
  final String initialView; // 'auth', 'forgot-password', 'reset-password'
  final String? resetToken;

  const LoginRegisterDialog({
    super.key,
    this.initialView = 'auth',
    this.resetToken,
  });

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
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Toast
            if (_toastMessage != null) _buildToast(),

            // Content based on view
            Flexible(
              child: _currentView == 'auth'
                  ? _buildAuthView()
                  : _currentView == 'forgot-password'
                      ? _buildForgotPasswordView()
                      : _buildResetPasswordView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (_currentView) {
      case 'forgot-password':
        title = 'Resetowanie hasła';
        break;
      case 'reset-password':
        title = 'Nowe hasło';
        break;
      default:
        title = 'Logowanie / Rejestracja';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentView != 'auth')
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentView = 'auth'),
            ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToast() {
    Color bgColor;
    IconData icon;

    switch (_toastType) {
      case 'success':
        bgColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'error':
        bgColor = Colors.red;
        icon = Icons.error;
        break;
      default:
        bgColor = Colors.blue;
        icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _toastMessage!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => setState(() => _toastMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // AUTH VIEW (Login/Register)
  // ============================================================================

  Widget _buildAuthView() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Logowanie'),
            Tab(text: 'Rejestracja'),
          ],
        ),
        Flexible(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLoginTab(),
              _buildRegisterTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // OAuth buttons
          _buildOAuthButtons('Zaloguj się szybciej'),

          const SizedBox(height: 16),
          _buildDivider('lub'),
          const SizedBox(height: 16),

          // Login form
          Form(
            key: _loginFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _loginEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loginPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureLoginPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                          () => _obscureLoginPassword = !_obscureLoginPassword),
                    ),
                  ),
                  obscureText: _obscureLoginPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Hasło jest wymagane';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zaloguj się'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _currentView = 'forgot-password'),
                  child: const Text('Zapomniałeś hasła?'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // OAuth buttons
          _buildOAuthButtons('Zarejestruj się szybciej'),

          const SizedBox(height: 16),
          _buildDivider('lub'),
          const SizedBox(height: 16),

          // Register form
          Form(
            key: _registerFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _registerEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _registerPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegisterPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(() =>
                          _obscureRegisterPassword = !_obscureRegisterPassword),
                    ),
                  ),
                  obscureText: _obscureRegisterPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Hasło jest wymagane';
                    }
                    return null;
                  },
                ),

                // Password requirements
                _buildPasswordRequirements(),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Potwierdź hasło',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Potwierdź hasło';
                    }
                    if (value != _registerPasswordController.text) {
                      return 'Hasła nie są identyczne';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zarejestruj się'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthButtons(String label) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _handleOAuthLogin('google'),
          icon: Image.network(
            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
            height: 18,
            width: 18,
            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 18),
          ),
          label: const Text('Kontynuuj z Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _handleOAuthLogin('github'),
          icon: const Icon(Icons.code, size: 18),
          label: const Text('Kontynuuj z GitHub'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    if (_registerPasswordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final requirements = [
      ('length', 'Co najmniej 8 znaków'),
      ('lowercase', 'Jedna mała litera (a-z)'),
      ('uppercase', 'Jedna duża litera (A-Z)'),
      ('number', 'Jedna cyfra (0-9)'),
      ('special', 'Jeden znak specjalny (!@#\$%^&*)'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wymagania hasła:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...requirements.map((req) {
            final met = _passwordRequirements[req.$1] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: met ? Colors.green : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: met
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    req.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: met ? Colors.green : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // FORGOT PASSWORD VIEW
  // ============================================================================

  Widget _buildForgotPasswordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _forgotFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 64),
            const SizedBox(height: 16),
            Text(
              'Podaj swój adres email, a wyślemy Ci link do resetowania hasła.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _forgotEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Wyślij link'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // RESET PASSWORD VIEW
  // ============================================================================

  Widget _buildResetPasswordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.password, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Wprowadź nowe hasło dla swojego konta.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _resetPasswordController,
              decoration: InputDecoration(
                labelText: 'Nowe hasło',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureResetPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                      () => _obscureResetPassword = !_obscureResetPassword),
                ),
              ),
              obscureText: _obscureResetPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Hasło jest wymagane';
                }
                if (value.length < 8) {
                  return 'Hasło musi mieć min. 8 znaków';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _resetConfirmController,
              decoration: InputDecoration(
                labelText: 'Potwierdź nowe hasło',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureResetConfirm
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                      () => _obscureResetConfirm = !_obscureResetConfirm),
                ),
              ),
              obscureText: _obscureResetConfirm,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Potwierdź hasło';
                }
                if (value != _resetPasswordController.text) {
                  return 'Hasła nie są identyczne';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Zmień hasło'),
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
      return 'Email jest wymagany';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Nieprawidłowy adres email';
    }
    return null;
  }
}

