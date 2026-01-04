import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/flashcards_provider.dart';
import 'providers/exams_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/workspace_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'data/cache/cache_manager.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  final apiService = ApiService();
  apiService.init();

  final subscriptionService = SubscriptionService(apiService);

  // Initialize local cache
  final cacheManager = CacheManager();
  await cacheManager.init();

  runApp(TorchEdApp(subscriptionService: subscriptionService));
}

class TorchEdApp extends StatelessWidget {
  final SubscriptionService subscriptionService;

  const TorchEdApp({super.key, required this.subscriptionService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => FlashcardsProvider()),
        ChangeNotifierProvider(create: (_) => ExamsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(subscriptionService)),
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    final router = AppRouter(authProvider).router;

    return MaterialApp.router(
      title: 'TorchED',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.materialThemeMode,

      // Routing
      routerConfig: router,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('pl'),
        Locale('de'),
        Locale('es'),
        Locale('fr'),
      ],
      locale: const Locale('pl'), // Default locale
    );
  }
}
