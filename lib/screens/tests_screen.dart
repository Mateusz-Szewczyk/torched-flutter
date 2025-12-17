import 'package:flutter/material.dart';

// Tests screen - equivalent to app/tests/page.tsx

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testy'),
      ),
      body: const Center(
        child: Text('Tests Screen - To be implemented'),
      ),
    );
  }
}

