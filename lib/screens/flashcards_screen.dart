import 'package:flutter/material.dart';

// Flashcards screen - equivalent to app/flashcards/page.tsx

class FlashcardsScreen extends StatelessWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiszki'),
      ),
      body: const Center(
        child: Text('Flashcards Screen - To be implemented'),
      ),
    );
  }
}

