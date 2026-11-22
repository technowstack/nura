import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/attributions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/url_opener.dart';
import '../../../core/widgets/nura_card.dart';

/// Static screen: every data source and license, from [kAttributions].
class AttributionView extends StatelessWidget {
  const AttributionView({super.key, this.opener = const DefaultUrlOpener()});

  final UrlOpener opener;

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
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SelectableText(
                          l,
                          onTap: () => _open(context, l),
                          style: text.bodyMedium?.copyWith(
                            color: scheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
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

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await opener.open(url);
    } on Object {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NuraSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tautan tidak dapat dibuka.',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: NuraSpace.s8),
              SelectableText(url),
              const SizedBox(height: NuraSpace.s12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Salin tautan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
