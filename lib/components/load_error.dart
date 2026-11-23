import 'package:flutter/material.dart';

import '../constants.dart';

/// Message with a "Try again" button, shown when data fails to load.
class LoadError extends StatelessWidget {
  const LoadError({
    super.key,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;

  /// Smaller version for use inside a section rather than a whole page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: defaultPadding),
            ],
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: defaultPadding / 2),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                maximumSize: const Size(220, 48),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Try again"),
            ),
          ],
        ),
      ),
    );
  }
}
