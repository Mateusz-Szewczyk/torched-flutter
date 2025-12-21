// Tests/Exams screen - exports ExamsScreen for routing
// This re-exports the ExamsScreen to maintain compatibility with existing routes

export 'exams_screen.dart';

import 'package:flutter/material.dart';
import 'exams_screen.dart';

/// TestsScreen is now an alias for ExamsScreen
/// Keeps backward compatibility with existing routes
class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExamsScreen();
  }
}

