import 'package:flutter/material.dart';

// Reset Password screen - equivalent to app/reset-password/page.tsx

class ResetPasswordScreen extends StatelessWidget {
  final String? token;

  const ResetPasswordScreen({this.token, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resetuj hasło'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 64),
            const SizedBox(height: 16),
            Text(
              'Resetowanie hasła',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (token != null) ...[
              const SizedBox(height: 8),
              Text('Token: ${token!.substring(0, 10)}...'),
            ],
          ],
        ),
      ),
    );
  }
}

