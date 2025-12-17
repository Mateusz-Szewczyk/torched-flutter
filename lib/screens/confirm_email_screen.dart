import 'package:flutter/material.dart';

// Confirm Email screen - equivalent to app/confirm-email/page.tsx

class ConfirmEmailScreen extends StatelessWidget {
  final String? token;

  const ConfirmEmailScreen({this.token, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Potwierdź email'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Potwierdzanie adresu email...',
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

