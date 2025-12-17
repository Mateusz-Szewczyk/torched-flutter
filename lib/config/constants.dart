// Application constants and configuration

class AppConfig {
  // API Configuration
  // Flask API (localhost:14440) - User management, auth
  static const String defaultFlaskApiUrl = 'http://localhost:14440/api/v1';
  // RAG API (localhost:8043) - Chat, flashcards, exams, files
  static const String defaultRagApiUrl = 'http://localhost:8043/api';

  // Get from environment or use default
  static String get flaskApiUrl =>
      const String.fromEnvironment('FLASK_API_URL', defaultValue: defaultFlaskApiUrl);

  static String get ragApiUrl =>
      const String.fromEnvironment('RAG_API_URL', defaultValue: defaultRagApiUrl);

  // Legacy aliases for compatibility
  static String get apiBaseUrl => flaskApiUrl;
  static String get ragBaseUrl => ragApiUrl;

  // ============================================================================
  // FLASK API ENDPOINTS (User management)
  // ============================================================================
  static const String authEndpoint = '/auth';  // Login, register, OAuth, password reset

  // ============================================================================
  // RAG API ENDPOINTS (Main functionality)
  // ============================================================================
  static const String chatsEndpoint = '/chats';           // Conversations & messages
  static const String decksEndpoint = '/decks';           // Flashcard decks
  static const String flashcardsEndpoint = '/flashcards'; // Individual flashcards
  static const String examsEndpoint = '/exams';           // Exams/tests
  static const String filesEndpoint = '/files';           // File uploads
  static const String studySessionsEndpoint = '/study_sessions'; // Study sessions

  // Legacy endpoint names (for compatibility)
  static const String conversationEndpoint = '/chats';
  static const String sharingEndpoint = '/sharing';

  // Storage Keys
  static const String jwtTokenKey = 'TorchED_auth';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';

  // OAuth Configuration (via Flask API)
  static const String googleOAuthUrl = '/auth/google';
  static const String githubOAuthUrl = '/auth/github';
  static const String oauthCallbackScheme = 'torched';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration longApiTimeout = Duration(seconds: 60);

  // Pagination
  static const int defaultPageSize = 20;

  // Flashcards
  static const int maxFlashcardsPerDeck = 500;

  // File Upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedFileTypes = ['pdf', 'txt', 'doc', 'docx'];

  // Supported Languages
  static const List<String> supportedLanguages = ['en', 'pl', 'de', 'es', 'fr'];
  static const String defaultLanguage = 'en';

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}

// Route names
class Routes {
  static const String home = '/';
  static const String chat = '/chat';
  static const String flashcards = '/flashcards';
  static const String tests = '/tests';
  static const String confirmEmail = '/confirm-email';
  static const String resetPassword = '/reset-password';
  static const String studyDeck = '/flashcards/study';
  static const String studyExam = '/tests/study';
}

// Error Messages
class ErrorMessages {
  static const String networkError = 'Network error. Please check your connection.';
  static const String authError = 'Authentication failed. Please login again.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  static const String sessionExpired = 'Your session has expired. Please login again.';
  static const String accessDenied = 'Access denied.';
}

