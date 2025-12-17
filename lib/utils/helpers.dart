// Utility functions and helpers

class Helpers {
  // Format date strings
  static String formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  // Validate email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Validate password strength
  static bool isStrongPassword(String password) {
    // At least 8 characters
    if (password.length < 8) return false;

    // Has uppercase
    if (!password.contains(RegExp(r'[A-Z]'))) return false;

    // Has lowercase
    if (!password.contains(RegExp(r'[a-z]'))) return false;

    // Has number
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    return true;
  }

  // Truncate text
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Calculate reading time
  static String calculateReadingTime(String text) {
    final wordCount = text.split(' ').length;
    final minutes = (wordCount / 200).ceil(); // Average reading speed: 200 words/min

    if (minutes < 1) {
      return 'Less than 1 min';
    } else if (minutes == 1) {
      return '1 min';
    } else {
      return '$minutes min';
    }
  }
}

