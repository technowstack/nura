import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centered title, optional description and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.description = '',
    this.action,
    super.key,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (description.isNotEmpty) ...[
              const SizedBox(height: NuraSpace.s8),
              Text(
                description,
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action case final action?) ...[
              const SizedBox(height: NuraSpace.s16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
