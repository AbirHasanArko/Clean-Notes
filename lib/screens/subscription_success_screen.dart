import 'package:flutter/material.dart';

import '../models/subscriber.dart';

/// Brief confirmation screen shown after successful OTP verification.
///
/// The actual route swap to [NotesListScreen] happens when the user taps
/// "Continue". The gate's state is already updated so that re-entry to
/// the gate (e.g. logout) is the only path back here.
class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({
    required this.subscriber,
    required this.onContinue,
    super.key,
  });

  final Subscriber subscriber;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskedPhone = _maskPhone(subscriber.phone);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 56,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You\'re subscribed!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to Clean Notes. Your subscription for '
                    '$maskedPhone is active.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue to notes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    final head = phone.substring(0, 4);
    final tail = phone.substring(phone.length - 3);
    return '$head •••• $tail';
  }
}