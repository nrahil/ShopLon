import 'package:flutter/material.dart';

import '../constants.dart';

/// Bottom-sheet content showing a title and label/value rows.
class InfoSheet extends StatelessWidget {
  const InfoSheet({super.key, required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding / 2, vertical: defaultPadding / 2),
          child: Row(
            children: [
              const BackButton(),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(defaultPadding),
            children: [
              for (final entry in rows.entries) ...[
                Text(
                  entry.key,
                  style: theme.textTheme.titleSmall!
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: defaultPadding / 4),
                Text(entry.value, style: const TextStyle(height: 1.5)),
                const SizedBox(height: defaultPadding),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
