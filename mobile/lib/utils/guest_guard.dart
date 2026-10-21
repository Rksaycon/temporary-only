// lib/utils/guest_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/providers/auth_provider.dart';

class GuestGuard {
  /// Returns true if the current user is a guest.
  static bool isGuest(WidgetRef ref) {
    return ref.read(authProvider).isGuest;
  }

  /// Shows a dialog prompting guest to sign up.
  static Future<void> showGuestRestrictionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feature Limited for Guests'),
        content: const Text(
          'You are using the app as a guest. To submit reports, request documents, and access all features, please create a free account or sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to sign up screen
              Navigator.pushNamed(context, '/register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C229C),
            ),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}