import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Error message with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.description,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: title,
    description: description,
    action: FilledButton.icon(
      onPressed: onRetry,
      icon: const NuraIcon(NuraIcons.refresh),
      label: const Text('Coba lagi'),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
