import 'package:flutter_test/flutter_test.dart';
import 'package:torch_ed_flutter/utils/helpers.dart';

void main() {
  group('Helpers', () {
    group('Email Validation', () {
      test('validates correct email addresses', () {
        expect(Helpers.isValidEmail('test@example.com'), true);
        expect(Helpers.isValidEmail('user.name@domain.co.uk'), true);
        expect(Helpers.isValidEmail('test+tag@example.com'), true);
      });

      test('rejects invalid email addresses', () {
        expect(Helpers.isValidEmail('invalid'), false);
        expect(Helpers.isValidEmail('test@'), false);
        expect(Helpers.isValidEmail('@example.com'), false);
        expect(Helpers.isValidEmail('test @example.com'), false);
      });
    });

    group('Password Strength', () {
      test('validates strong passwords', () {
        expect(Helpers.isStrongPassword('Test1234'), true);
        expect(Helpers.isStrongPassword('MyP@ssw0rd'), true);
        expect(Helpers.isStrongPassword('Secure123'), true);
      });

      test('rejects weak passwords', () {
        expect(Helpers.isStrongPassword('short'), false);
        expect(Helpers.isStrongPassword('alllowercase123'), false);
        expect(Helpers.isStrongPassword('ALLUPPERCASE123'), false);
        expect(Helpers.isStrongPassword('NoNumbers'), false);
        expect(Helpers.isStrongPassword('12345678'), false);
      });
    });

    group('Text Truncation', () {
      test('truncates long text', () {
        final longText = 'This is a very long text that should be truncated';
        expect(Helpers.truncate(longText, 10), 'This is a ...');
      });

      test('does not truncate short text', () {
        final shortText = 'Short';
        expect(Helpers.truncate(shortText, 10), 'Short');
      });
    });

    group('Reading Time', () {
      test('calculates reading time correctly', () {
        final text = 'word ' * 200; // 200 words
        expect(Helpers.calculateReadingTime(text), '1 min');

        final longText = 'word ' * 500; // 500 words
        expect(Helpers.calculateReadingTime(longText), '3 min');

        final shortText = 'word ' * 50; // 50 words
        expect(Helpers.calculateReadingTime(shortText), 'Less than 1 min');
      });
    });

    group('Date Formatting', () {
      test('formats dates correctly', () {
        final today = DateTime.now().toIso8601String();
        expect(Helpers.formatDate(today), 'Today');

        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String();
        expect(Helpers.formatDate(yesterday), 'Yesterday');

        final twoDaysAgo = DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String();
        expect(Helpers.formatDate(twoDaysAgo), '2 days ago');
      });

      test('handles null dates', () {
        expect(Helpers.formatDate(null), '');
      });
    });
  });
}

