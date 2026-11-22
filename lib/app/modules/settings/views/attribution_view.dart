import 'package:flutter/material.dart';

import '../../../core/attributions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';

/// Static screen: every data source and license, from [kAttributions].
class AttributionView extends StatelessWidget {
  const AttributionView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sumber & Atribusi')),
      body: ListView(
        padding: const EdgeInsets.all(NuraSpace.s16),
        children: [
          for (final a in kAttributions) ...[
            NuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(a.title, style: text.titleMedium),
                  ),
                  for (final c in a.credits) ...[
                    const SizedBox(height: NuraSpace.s8),
                    Text(c, style: text.bodyMedium),
                  ],
                  const SizedBox(height: NuraSpace.s8),
                  Text(
                    a.licenseNote,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (final l in a.links) ...[
                    const SizedBox(height: NuraSpace.s8),
                    SelectableText(
                      l,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: NuraSpace.s12),
          ],
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Nura'),
              child: const Text('Lisensi perangkat lunak'),
            ),
          ),
        ],
      ),
    );
  }
}
