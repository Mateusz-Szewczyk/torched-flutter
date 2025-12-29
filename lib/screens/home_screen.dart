import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard_widget.dart';

// Home screen - equivalent to app/page.tsx (Dashboard)
// Shows Dashboard for logged-in users, welcome screen for guests

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading while checking auth
    if (authProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show Dashboard for authenticated users (no Scaffold - MainLayout provides it)
    if (authProvider.isAuthenticated) {
      return const DashboardWidget();
    }

    // Show welcome screen for guests (no Scaffold - MainLayout provides it)
    return SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 48,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Your learning starts and ends here',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Combine exams, flashcards, and intelligent chat in one place.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Info cards
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _InfoCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'AI Chat',
                        description: 'Talk to your AI assistant',
                        color: Colors.blue,
                      ),
                      _InfoCard(
                        icon: Icons.style_outlined,
                        title: 'Flashcards',
                        description: 'Learn with flashcards',
                        color: Colors.green,
                      ),
                      _InfoCard(
                        icon: Icons.quiz_outlined,
                        title: 'Tests',
                        description: 'Test your knowledge',
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Login prompt
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Log in to access your dashboard',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track your progress, study streak, and more',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24), // Bottom padding for scroll
                ],
              ),
            ),
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha(75),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

