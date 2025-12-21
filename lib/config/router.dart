import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/tests_screen.dart';
import '../screens/confirm_email_screen.dart';
import '../screens/reset_password_screen.dart';
import '../layouts/main_layout.dart';
import '../providers/auth_provider.dart';
import 'constants.dart';

// Router configuration - equivalent to Next.js routing

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: authProvider,

    // Redirect logic for auth
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;

      // Public routes that don't require auth
      final publicRoutes = [
        Routes.confirmEmail,
        Routes.resetPassword,
      ];

      // Don't redirect while loading
      if (isLoading) {
        return null;
      }

      final isPublicRoute = publicRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isPublicRoute) {
        return Routes.home; // Will show login dialog
      }

      return null;
    },

    routes: [
      // Shell route with MainLayout for all routes except public ones
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          // Home / Dashboard
          GoRoute(
            path: Routes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),

          // Chat - both with and without conversation ID
          GoRoute(
            path: Routes.chat,
            name: 'chat',
            builder: (context, state) => const ChatScreen(),
            routes: [
              // Chat with specific conversation ID (deep link support)
              GoRoute(
                path: ':conversationId',
                name: 'chat-conversation',
                builder: (context, state) {
                  final conversationId = state.pathParameters['conversationId'];
                  return ChatScreen(
                    initialConversationId: int.tryParse(conversationId ?? ''),
                  );
                },
              ),
            ],
          ),

          // Flashcards
          GoRoute(
            path: Routes.flashcards,
            name: 'flashcards',
            builder: (context, state) => const FlashcardsScreen(),
            routes: [
              GoRoute(
                path: 'study/:deckId',
                name: 'study-deck',
                builder: (context, state) {
                  final deckId = state.pathParameters['deckId'];
                  return StudyDeckScreen(deckId: int.parse(deckId!));
                },
              ),
            ],
          ),

          // Tests / Exams
          GoRoute(
            path: Routes.tests,
            name: 'tests',
            builder: (context, state) => const TestsScreen(),
            routes: [
              GoRoute(
                path: 'study/:examId',
                name: 'study-exam',
                builder: (context, state) {
                  final examId = state.pathParameters['examId'];
                  return StudyExamScreen(examId: int.parse(examId!));
                },
              ),
            ],
          ),
        ],
      ),

      // Confirm Email (public)
      GoRoute(
        path: Routes.confirmEmail,
        name: 'confirm-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ConfirmEmailScreen(token: token);
        },
      ),

      // Reset Password (public)
      GoRoute(
        path: Routes.resetPassword,
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(token: token);
        },
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.error.toString()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

// Placeholder screens (will be implemented later)
class StudyDeckScreen extends StatelessWidget {
  final int deckId;

  const StudyDeckScreen({required this.deckId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Study Deck $deckId')),
      body: Center(child: Text('Deck $deckId study screen - TODO')),
    );
  }
}

class StudyExamScreen extends StatelessWidget {
  final int examId;

  const StudyExamScreen({required this.examId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Study Exam $examId')),
      body: Center(child: Text('Exam $examId study screen - TODO')),
    );
  }
}



